package XML::Struct::Writer;
# ABSTRACT: Write XML data structures to XML streams
# VERSION

use strict;
use Moo;
use XML::LibXML::SAX::Builder;
use Scalar::Util qw(blessed);

has handler => (
    is => 'rw',
    default => sub { XML::LibXML::SAX::Builder->new( handler => $_[0] ); }
);

has attributes => (is => 'rw', default => sub { 1 });
has encoding   => (is => 'rw', default => sub { 'UTF-8' });
has version    => (is => 'rw', default => sub { '1.0' });

# TODO: use a stream-based writer if option 'to' is set
has to     => (is => 'rw'); # toFile(filename), toFH(GLOB|IO::Handle)
has pretty => (is => 'rw', default => sub { 0 }); # 0|1|2

sub write {
    my ($self, $root) = @_;

    $self->writeStart;
    $self->writeElement($root);
    $self->writeEnd;
    
    return $self->handler->result if $self->handler->can('result');
}

*writeDocument = \&write;

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
                    $self->writeCharacters($child);
                }
            }
        }

        $self->writeEndElement($element);
    }
}

sub writeStartElement {
    my ($self, $element) = @_;

    my $attr = $element->[1];
      if ($self->attributes and $attr) {
          $self->handler->start_element( {
              Name => $element->[0],
              Attributes => { map { $_ => { Name => $_, Value => $attr->{$_}} } keys %$attr },
          } );
    } else {
        $self->handler->start_element( { 
            Name => $element->[0] 
        } );
    }
}

sub writeEndElement {
    my ($self, $element) = @_;
    $self->handler->end_element( { Name => $element->[0] } );
}

sub writeCharacters {
    $_[0]->handler->characters({ Data => $_[1] });
}

sub writeStart {
    my $self = shift;
    $self->handler->start_document;
    $self->handler->xml_decl({
        Version => $self->version, Encoding => $self->encoding
    }) if $self->handler->can('xml_decl');
    $self->writeStartElement($_[0]) if @_;
}

sub writeEnd {
    my $self = shift;
    $self->writeEndElement($_[0]) if @_;
    $self->handler->end_document;
}

=head1 SYNOPSIS

    use XML::Struct::Writer;

    my $xml = XML::Struct::Writer->new->write( [
        greet => { }, [
            "Hello, ",
            [ emph => { color => "blue" } , [ "World" ] ],
            "!"
        ]
    ] ); 
    $xml->toFile("greet.xml");

    # <?xml version="1.0" encoding="UTF-8"?>
    # <greet>Hello, <emph color="blue">World</emph>!</greet>

    XML::Struct::Writer->new( attributes => 0 )->write( [
        doc => [ 
            [ name => [ "alice" ] ],
            [ name => [ "bob" ] ],
        ] 
    ] )->serialize(1); # 1 == pretty

    # <?xml version="1.0" encoding="UTF-8"?>
    # <doc>
    #  <name>alice</name>
    #  <name>bob</name>
    # </doc>

=head1 DESCRIPTION

This module writes an XML document, given as L<XML::Struct> data structure.

L<XML::Struct::Writer> can act as SAX event generator that sequentially sends
L</"SAX EVENTS"> to a SAX handler. The default handler
L<XML::LibXML::SAX::Builder> creates L<XML::LibXML::Document> that can be used
to serialize the XML document as string.

=method write( $root ) ==  writeDocument( $root )

Write an XML document, given in form of its root element, to the handler.  If
the handler implements a C<result()> method, it is used to get a return value.

For most applications this is the only method one needs to care about. If the
XML document to be written is not fully given as root element, one has to
directly call the following methods. This method is basically equivalent to:

    $writer->writeStart;
    $writer->writeElement($root);
    $writer->writeEnd;
    $writer->result if $writer->can('result');

=method writeStart( [ $root ] )

Call the handler's C<start_document> and C<xml_decl> methods. An optional root
element can be passed, so C<< $writer->writeStart($root) >> is equivalent to:

    $writer->writeStart;
    $writer->writeStartElement($root);

=method writeElement( $element [, @more_elements ] )

Write one or more XML elements, including their child elements, to the handler.

=method writeStartElement( $element )

Directly call the handler's C<start_element> method.

=method writeEndElement( $element )

Directly call the handler's C<end_element> method.

=method writeCharacters( $string )

Directy call the handler's C<characters> method.

=method writeEnd( [ $root ] )

Directly call the handler's C<end_document> method. An optional root element
can be passed, so C<< $writer->writeEnd($root) >> is equivalent to:

    $writer->writeEndElement($root);
    $writer->writeEnd;

=head1 CONFIGURATION

=over

=item C<handler>

Specify a SAX handler that L</"SAX EVENTS"> are send to. 

=item C<attributes>

Set to true by default to expect attribute hashes in the L<XML::Struct> input
format. If set to false, XML elements must be passed as

    [ $name => \@children ]

instead of
    
    [ $name => \%attributes, \@children ]

=item encoding

Sets the encoding for handlers that support an explicit encoding. Set to UTF-8
by default.

=back

=head1 SAX EVENTS

A SAX handler, as used by this module, is expected to implement the following
methods (two of them are optional):

=over

=item xml_decl( { Version => $version, Encoding => $encoding } )

Optionally called once at the start of an XML document, if the handler supports
this method.

=item start_document()

Called once at the start of an XML document.

=item start_element( { Name => $name, Attributes => \%attributes } )

Called at the start of an XML element to emit an XML start tag.

=item end_element( { Name => $name } )

Called at the end of an XML element to emit an XML end tag.

=item characters( { Data => $characters } )

Called for character data. Character entities and CDATA section are expanded to
strings.

=item end_document()

Called once at the end of an XML document.

=item result()

Optionally called at the end of C<write>/C<writeDocument> to return a value
from this methods. Handlers do not need to implement this method.

=back

=head1 SEE ALSO

Using a streaming SAX handler, such as L<XML::SAX::Writer>,
L<XML::Genx::SAXWriter>, L<XML::Handler::YAWriter>, and possibly L<XML::Writer>
should be more performant for serialization. Examples of other modules that
receive SAX events include L<XML::STX>, L<XML::SAX::SimpleDispatcher>, and
L<XML::SAX::Machines>,

=encoding utf8

=cut

1;
