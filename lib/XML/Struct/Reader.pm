package XML::Struct::Reader;
# ABSTRACT: Read XML stream into XML data structures
# VERSION

use strict;
use Moo;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use XML::Struct;

has whitespace => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });
has path       => (is => 'rw', default => sub { '*' }, isa => \&_checkPath);
has stream     => (is => 'rw'); # TODO: check with isa
has from       => (is => 'rw', trigger => 1);

has hashify    => (is => 'rw', default => sub { 0 });
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

This module reads from an XML stream via L<XML::LibXML::Reader> and return a
Perl data structure with ordered XML (see L<XML::Struct>).

=head1 CONFIGURATION

=over 4

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
pass a stream parameter to the C<read*> methods. Setting a source with option
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

A path is a very reduced form of an XPath expressions (no axes, no "C<..>" or
C<//>, no node tests...). Namespaces are not supported yet.

=item C<whitespace>

Include ignorable whitespace as text elements (disabled by default)

=method read = readNext ( $stream [, $path ] )

Read the next XML element from a stream. If no path option is specified, the
reader's path option is used ("C<*>" by default, first matching the root, then
every other element). 

=cut


sub _checkPath {
    my $path = shift;
    die "invalid path: $path" if $path =~ qr{\.\.|//|^\.};
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

    $path .= '*' if $path =~ qr{/$};

    my @parts = split '/', $path;
    my $relative = $parts[0] ne '';

    while(1) { 
        return if !$stream->read; # end or error
        next if $stream->nodeType != XML_READER_TYPE_ELEMENT;

#        printf " %d=%d %s:%s==%s\n", $stream->depth, scalar @parts, $stream->nodePath, $stream->name, join('/', @parts);

        if ($relative) {
            if (_nameMatch($parts[0], $stream->name)) {
                last;
            }
        } else {
            if (!_nameMatch($parts[$stream->depth+1], $stream->name)) {
                $stream->nextSibling();
            } elsif ($stream->depth == scalar @parts - 2) {
                last;
            }
        }
    } 

    my $xml = $self->readElement($stream);
    return $self->hashify 
        ? XML::Struct::hashifyXML( $xml, root => $self->root ) : $xml;
}

*read = \&readNext;

=method readElement( [ $stream ] )

Read an XML element from a stream and return it as array reference with element name,
attributes, and child elements. In contrast to method C<read>, this method expects
the stream to be at an element node (C<< $stream->nodeType == 1 >>) or bad things
might happed.

=cut

sub readElement {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    my @element = ($stream->name);

    if ($self->attributes) {
        my $attr = $self->readAttributes($stream);
        my $children = $self->readContent($stream) if !$stream->isEmptyElement;
        if ($children) {
            push @element, $attr || { }, $children;
        } elsif( $attr ) {
            push @element, $attr;
        }
    } elsif( !$stream->isEmptyElement ) {
        push @element, $self->readContent($stream);
    }

    return \@element;
}

=method readAttributes( [ $stream ] )

Read all XML attributes from a stream and return a hash reference or an empty
list if no attributes were found.

=cut

sub readAttributes {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    return unless $stream->moveToFirstAttribute == 1;

    my $attr = { };
    do {
        $attr->{$stream->name} = $stream->value;
    } while ($stream->moveToNextAttribute);
    $stream->moveToElement;

    return $attr;
}

=method readContent( [ $stream ] )

Read all child elements of an XML element and return the result as array
reference or as empty list if no children were found.  Significant whitespace
is only included if option C<whitespace> is enabled.

=cut

sub readContent {
    my $self   = shift;
    my $stream = @_ ? shift : $self->stream;

    my @children;
    while(1) {
        $stream->read;
        my $type = $stream->nodeType;

        if (!$type or $type == XML_READER_TYPE_END_ELEMENT) {
            return @children ? \@children : (); 
        }

        if ($type == XML_READER_TYPE_ELEMENT) {
            push @children, $self->readElement($stream);
        } elsif ($type == XML_READER_TYPE_TEXT or $type == XML_READER_TYPE_CDATA ) {
            push @children, $stream->value;
        } elsif ($type == XML_READER_TYPE_SIGNIFICANT_WHITESPACE && $self->whitespace) {
            push @children, $stream->value;
        }
    }
}

1;
