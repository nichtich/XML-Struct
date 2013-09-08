package XML::Struct::Writer;
# ABSTRACT: Process ordered XML as stream, for instance to write XML
# VERSION

use strict;
use Moo;
use XML::LibXML::SAX::Builder;

has handler => (
    is => 'rw',
    default => sub { XML::LibXML::SAX::Builder->new( handler => $_[0] ); }
);

has attributes => (is => 'rw', default => sub { 1 });

=method write( $root ) ==  writeDocument( $root )

Write an XML document, given in form of its root element, to the handler.
Returns the handler's result, if it support a C<result> method. 

=cut

sub write {
    my ($self, $root) = @_;
    $self->writeStart;
    $self->writeElement($root);
    $self->writeEnd;
    return $self->handler->result if $self->handler->can('result');
}

*writeDocument = \&write;

=method writeElement( $element [, @more_elements ] )

Write an XML element to the handler. Note that the default handler requires to
also call C<writeStart> and C<writeEnd> when using this method:

    $writer->writeStart( [ "root", { some => "attribute" } ] );
    $writer->writeElement( $element1 );
    $writer->writeElement( $element2, $element3 );
    ...
    $writer->writeEnd( [ "root" ] );

=cut

sub writeElement {
    my $self = shift;
    foreach my $element (@_) {

        my ($children, $attributes) = $self->attributes 
            ? ($element->[2], $element->[1]) : ($element->[1]);

        $self->writeStartElement($element);

        if ($children) {
            foreach my $child ( @$children ) {
                if (ref $child) {
                    $self->writeElement($child);
                } else {
                    $self->handler->characters({ Data => $child });
                }
            }
        }

        $self->writeEndElement($element);
    }
}

=method writeStartElement( $element )
=cut

sub writeStartElement {
    my ($self, $element) = @_;

    if ($self->attributes and $element->[1]) {
        $self->handler->start_element( { 
            Name => $element->[0],
            Attributes => $element->[1] 
        } );
    } else {
        $self->handler->start_element( { 
            Name => $element->[0] 
        } );
    }
}

=method writeEndElement( $element )
=cut

sub writeEndElement {
    my ($self, $element) = @_;
    $self->handler->end_element( { Name => $element->[0] } );
}

=method writeCharacters( $string )
=cut

sub writeCharacters {
    $_[0]->handler->characters({ Data => $_[1] });
}

=method writeStart( [ $root ] )

Call the handler's C<start_document> and optionally C<start_element>.  Calling
C<< $writer->writeStart($root) >> is equivalent to:

    $writer->writeStart;
    $writer->writeStartElement($root);

=cut

sub writeStart {
    my $self = shift;
    $self->handler->start_document;
    $self->writeStartElement($_[0]) if @_;
}

=method writeEnd( [ $root ] )

Call the handler's C<end_document> and optionally C<end_element>.  Calling C<<
$writer->writeEnd($root) >> is equivalent to:

    $writer->writeEndElement($root);
    $writer->writeEnd;

=cut

sub writeEnd {
    my $self = shift;
    $self->writeEndElement($_[0]) if @_;
    $self->handler->end_document;
}

=head1 SYNOPSIS

    use XML::Struct::Writer;

    my $writer = XML::Struct::Writer->new;
    my $xml = $writer->write( [
        greet => { }, [
            "Hello, ",
            [ emph => { color => "blue" } , [ "World" ] ],
            "!"
        ]
    ] ); 
    
    $xml->setEncoding("UTF-8");
    $xml->toFile("greet.xml");

    # <?xml version="1.0" encoding="UTF-8"?>
    # <greet>Hello, <emph color="blue">World</emph>!</greet>

    my $writer = XML::Struct::Writer->new( attributes => 0 );
    $writer->writeDocument( [
        doc => [ 
            [ name => [ "alice" ] ],
            [ name => [ "bob" ] ],
        ] 
    ] )->serialize(1);

    # <?xml version="1.0"?>
    # <doc>
    #  <name>alice</name>
    #  <name>bob</name>
    # </doc>

=head1 DESCRIPTION

This module transforms an XML document, given as in form of a data structure as
described in L<XML::Struct>, into a stream of SAX events. By default, the
stream is used to build a L<XML::LibXML::Document> that can be used for
instance to write the XML document to a file.

=head1 CONFIGURATION

The C<handler> property can be used to specify a SAX handler that XML stream
events are send to. By default L<XML::LibXML::SAX::Builder> is used to build a
DOM that is serialized afterwards. Using another handler should be more
performant for serialization. See L<XML::Writer>, L<XML::Handler::YAWriter>
(and possibly L<XML::SAX::Writer> combined with L<XML::Filter::SAX1toSAX2>) for
stream-based XML writers.

Handlers do not need to support all features of SAX. A handler is expected to
implement the following methods:

=over 4

=item start_document()

=item start_element( { Name => $name, Attributes => \%attributes } )

=item end_element( { Name => $name } )

=item characters( { Data => $characters } )

=item end_document()

=back

If the handler further implements a C<result()> method, it is called at the end
of C<writeDocument>.

If C<attributes> property is set to a false value (true by default), elements
are expected to be passed without attributes hash as implemented in
L<XML::Struct::Reader>.

=encoding utf8

=cut

1;
