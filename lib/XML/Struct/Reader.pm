package XML::Struct::Reader;
# ABSTRACT: Read XML streams into XML data structures
# VERSION

use strict;
use Moo;
use Carp qw(croak);
our @CARP_NOT = qw(XML::Struct);
use Scalar::Util qw(blessed);
use XML::Struct;

has whitespace => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });
has path       => (is => 'rw', default => sub { '*' }, isa => \&_checkPath);
has stream     => (is => 'rw'); # TODO: check with isa
has from       => (is => 'rw', trigger => 1);
has ns         => (is => 'rw', default => sub { 'keep' }, trigger => 1);
has depth      => (is => 'rw');
has simple     => (is => 'rw', default => sub { 0 });
has root       => (is => 'rw', default => sub { 0 });

use XML::LibXML::Reader qw(
    XML_READER_TYPE_ELEMENT
    XML_READER_TYPE_TEXT
    XML_READER_TYPE_CDATA
    XML_READER_TYPE_SIGNIFICANT_WHITESPACE
    XML_READER_TYPE_END_ELEMENT
); 

=head1 SYNOPSIS

    my $reader = XML::Struct::Reader->new( from => "file.xml" );
    my $data   = $reader->read;

=encoding utf8

=head1 DESCRIPTION

This module reads an XML stream (via L<XML::LibXML::Reader>) into
L<XML::Struct>/MicroXML data structures.

=head1 CONFIGURATION

=over

=item C<from>

A source to read from. Possible values include a string or string reference
with XML data, a filename, an URL, a file handle, and a hash reference with
options passed to L<XML::LibXML::Reader>.

=cut

sub _trigger_from {
    my ($self, $from) = @_;

    unless (blessed $from and $from->isa('XML::LibXML::Reader')) {
        my %options; 

        if (ref $from and ref $from eq 'HASH') {
            %options = %$from;
            $from = delete $options{from} if exists $options{from};
        }

        if (!defined $from or $from eq '-') {
            $options{IO} = \*STDIN
        } elsif( !ref $from and $from =~ /^</ ) {
            $options{string} = $from;
        } elsif( ref $from and ref $from eq 'SCALAR' ) {
            $options{string} = $$from;
        } elsif( ref $from and ref $from eq 'GLOB' ) {
            $options{FD} = $from;
        } elsif( blessed $from ) {
            $options{IO} = $from;
        } elsif( !ref $from ) {
            $options{location} = $from; # filename or URL
        } elsif( ! grep { $_ =~ /^(IO|string|location|FD|DOM)$/} keys %options ) {
            croak "invalid option 'from': $from";
        }
        
        $from = XML::LibXML::Reader->new( %options );
    }

    $self->stream( $from );
}

=item C<stream>

A L<XML::LibXML::Reader> to read from. If no stream has been defined, one must
pass a stream parameter to the C<read...> methods. Setting a source with option
C<from> automatically sets a stream.

=item C<attributes>

Include attributes (enabled by default). If disabled, the representation of
an XML element will be

   [ $name => \@children ]

instead of

   [ $name => \%attributes, \@children ]

=item C<path>

Optional path expression to be used as default value when calling C<read>.
Pathes must either be absolute (starting with "C</>") or consist of a single
element name. The special name "C<*>" matches all element names.

A path is a very reduced form of an XPath expressions (no axes, no "C<..>", no
node tests, C<//> only at the start...).  Namespaces are not supported yet.

=item C<whitespace>

Include ignorable whitespace as text elements (disabled by default)

=item C<ns>

Define how XML namespaces should be processed. By default (value 'C<keep>'),
this document:

    <doc>
      <x:foo xmlns:x="http://example.org/" bar="doz" />
    </doc>

is transformed to this structure, keeping namespace prefixes and declarations 
as unprocessed element names and attributes:
    
    [ 'doc', {}, [
        [
          'x:foo', {
              'bar' => 'doz',
              'xmlns:x' => 'http://example.org/'
          }
        ]
    ]

Setting this option to 'C<strip>' will remove all namespace prefixes and
namespace declaration attributes, so the result would be:

    [ 'doc', {}, [
        [
          'foo', {
              'bar' => 'doz'
          }
        ]
    ]

Setting this option to 'C<disallow>' results in an error when namespace
prefixes or declarations are read.

Expanding namespace URIs ('C<expand'>) is not supported yet.

=cut

sub _trigger_ns {
    my ($self, $ns) = @_;

    if (!defined $ns or $ns eq '') {
        $self->{ns} = 'keep';
    } elsif ($ns !~ /^(keep|strip|disallow)?$/) {
        croak "invalid option 'ns': $ns";
    }
}

=item C<simple>

Convert XML to simple key-value structure as known from L<XML::Simple>.

=item C<root>

When using option 'C<simple>' the root element is removed by default. Use this
option to keep the root or to further set its element name.

=item C<depth>

When option 'C<simple>' is enabled, only transform to a given depth.  This
option is useful for instance to access document-oriented XML embedded in data
oriented XML. All elements below the given depth will be returned as ordered
XML. Use any negative or non-numeric value for unlimited depth. The root
element only counts as one level if option C<root> is enabled.  Depth zero (and
depth one if with root) are only supported experimentally!

=back

=method read = readNext ( [ $stream ] [, $path ] )

Read the next XML element from a stream. If no path option is specified, the
reader's path option is used ("C<*>" by default, first matching the root, then
every other element). 

=cut

sub _checkPath {
    my $path = shift;

    die "invalid path: $path" if $path =~ qr{\.\.|.//|^\.};
    die "relative path not supported: $path" if $path =~ qr{^[^/]+/};

    return $path;
}

sub _nameMatch {
   return ($_[0] eq '*' or $_[0] eq $_[1]); 
}

sub readNext { # TODO: use XML::LibXML::Reader->nextPatternMatch for more performance
    my $self   = shift;
    my $stream = blessed $_[0] ? shift() : $self->stream;
    my $path   = defined $_[0] ? _checkPath($_[0]) : $self->path;

    $path =~ s{^//}{};
    $path .= '*' if $path =~ qr{^$|/$};

    my @parts = split '/', $path;
    my $relative = $parts[0] ne '';

    while(1) { 
        return if !$stream->read; # end or error
        next if $stream->nodeType != XML_READER_TYPE_ELEMENT;

#        printf " %d=%d %s:%s==%s\n", $stream->depth, scalar @parts, $stream->nodePath, $stream->name, join('/', @parts);

        my $name = $self->_name($stream);

        if ($relative) {
            if (_nameMatch($parts[0], $name)) {
                last;
            }
        } else {
            if (!_nameMatch($parts[$stream->depth+1], $name)) {
                $stream->nextSibling();
            } elsif ($stream->depth == scalar @parts - 2) {
                last;
            }
        }
    } 

    my $xml = $self->readElement($stream);
    return $self->simple 
        ? XML::Struct::simpleXML( $xml, 
            root => $self->root, 
            attributes => $self->attributes,
            depth => $self->depth 
        ) : $xml;
}

*read = \&readNext;

=method readDocument( [ $stream ] [, $path ] )

Read an entire XML document. In contrast to C<read>/C<readNext>, this method
always reads the entire stream. The return value is the first element (that is
the root element by default) in scalar context and a list of elements in array
context. Multiple elements can be returned for instance when a path was
specified to select document fragments.

=cut

sub readDocument {
    my $self = shift;
    my @document;
   
    while(my $element = $self->read(@_)) {
        push @document, $element;
    }

    return wantarray ? @document : $document[0];
}

sub _name {
    my ($self, $stream) = @_;

    if ($self->ns eq 'strip') {
        return $stream->localName;
    } elsif( $self->ns eq 'disallow' ) {
        if ( $stream->name =~ /^xmlns(:.*)?$/) {
            croak "namespaces not allowed at line ".$stream->lineNumber;
        }
    }

    return $stream->name;
}

=method readElement( [ $stream ] )

Read an XML element from a stream and return it as array reference with element name,
attributes, and child elements. In contrast to method C<read>, this method expects
the stream to be at an element node (C<< $stream->nodeType == 1 >>) or bad things
might happed.

=cut

sub readElement {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    my @element = ($self->_name($stream));

    if ($self->attributes) {
        my $attr = $self->readAttributes($stream);
        my $children = $stream->isEmptyElement ? [ ] : $self->readContent($stream);
        push @element, $attr, $children;
    } elsif( !$stream->isEmptyElement ) {
        push @element, $self->readContent($stream);
    }

    return \@element;
}

=method readAttributes( [ $stream ] )

Read all XML attributes from a stream and return a (possibly empty) hash
reference.

=cut

sub readAttributes {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    return { } if $stream->moveToFirstAttribute != 1;

    my $attr = { };
    do {
        if ($self->ns ne 'strip' or $stream->name !~ /^xmlns(:.*)?$/) {
            $attr->{ $self->_name($stream) } = $stream->value;
        }
    } while ($stream->moveToNextAttribute);
    $stream->moveToElement;

    return $attr;
}

=method readContent( [ $stream ] )

Read all child elements of an XML element and return the result as (possibly
empty) array reference.  Significant whitespace is only included if option
C<whitespace> is enabled.

=cut

sub readContent {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    my @children;
    while(1) {
        $stream->read;
        my $type = $stream->nodeType;

        last if !$type or $type == XML_READER_TYPE_END_ELEMENT;

        if ($type == XML_READER_TYPE_ELEMENT) {
            push @children, $self->readElement($stream);
        } elsif ($type == XML_READER_TYPE_TEXT or $type == XML_READER_TYPE_CDATA ) {
            push @children, $stream->value;
        } elsif ($type == XML_READER_TYPE_SIGNIFICANT_WHITESPACE && $self->whitespace) {
            push @children, $stream->value;
        }
    }
    
    return \@children; 
}

1;
