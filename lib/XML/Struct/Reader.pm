package XML::Struct::Reader;
# ABSTRACT: Read ordered XML from a stream
# VERSION

use strict;
use Moo;

has whitespace => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });

use XML::LibXML::Reader qw(
    XML_READER_TYPE_ELEMENT
    XML_READER_TYPE_TEXT
    XML_READER_TYPE_CDATA
    XML_READER_TYPE_SIGNIFICANT_WHITESPACE
    XML_READER_TYPE_END_ELEMENT
); 

=head1 SYNOPSIS

    my $stream = XML::LibXML::Reader->new( location => "file.xml" );
    my $stream = XML::Struct::Reader->new;
    my $data = $stream->read( $stream );

=endocing utf8

=head1 DESCRIPTION

This module reads from an XML stream via L<XML::LibXML::Reader> and return a
Perl data structure with ordered XML (see L<XML::Struct>).

=method new( %options )

Create a new reader. By default whitespace is ignored, unless enabled with
option C<whitespace>. The option C<attributes> can be set to false to omit
all attributes from the result.

=method read( $stream )

Read the root element or the next element element. This method is a shortcut
for C<< readNext( $stream, '*' ) >>.

=cut

sub read {
    my ($self, $stream) = @_;
    $self->readNext( $stream, '' );
}

=method readElement( $stream )

Read an XML element from a stream and return it as array reference with element name,
attributes, and child elements. In contrast to method C<read>, this method expects
the stream to be at an element node (C<< $stream->nodeType == 1 >>) or bad things
might happed.

=cut

sub readElement {
    my ($self, $stream) = @_;

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

=method readNext( $stream, $path )

Read the next element from a stream. The experimental option C<$path> can be
used to specify an element name (the empty string or "C<*>" match all element
nodes) and a path, such as C</some/element>. The path operator "C<../>" is not
supported.

=cut

sub readNext {
    my ($self, $stream, $path) = @_;

    $path = "./$path" if $path !~ qr{^[./]};
    $path .= '*' if $path =~ qr{/$};

    # TODO: check and normalize Path
    # print "path='$path'";

    my @parts = split '/', $path;
    my $depth = scalar @parts - 2;
    $depth += $stream->depth if $parts[0] eq '.'; # relative path

    my $name = $parts[-1];

    do { 
        return if !$stream->read; # error
        # printf "%d %s\n", ($stream->depth, $stream->nodePath) if $stream->nodeType == 1;
    } while( 
        $stream->nodeType != XML_READER_TYPE_ELEMENT or $stream->depth != $depth or 
        ($name ne '*' and $stream->name ne $name)
        # TODO: check full $stream->nodePath and possibly skip subtrees
        );

    $self->readElement($stream);
}

=head readAttributes( $stream )

Read all XML attributes from a stream and return a hash reference or an empty
list if no attributes were found.

=cut

sub readAttributes {
    my ($self, $stream) = @_;
    return unless $stream->moveToFirstAttribute == 1;

    my $attr = { };
    do {
        $attr->{$stream->name} = $stream->value;
    } while ($stream->moveToNextAttribute);
    $stream->moveToElement;

    return $attr;
}

=method readContent( $stream )

Read all child elements of an XML element and return the result as array
reference or as empty list if no children were found.  Significant whitespace
is only included if option C<whitespace> is enabled.

=cut

sub readContent {
    my ($self, $stream) = @_;

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
