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

=method writeDocument( $root )
=cut

sub writeDocument {
    my ($self, $root) = @_;
    $self->handler->start_document;
    $self->writeElement($root);
    $self->handler->end_document;
    return $self->handler->result if $self->handler->can('result');
}

=method writeElement( $element )
=cut

sub writeElement {
    my ($self, $element) = @_;

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

    $self->writeEndElement;
}

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

sub writeEndElement {
    my ($self, $element) = @_;
    $self->handler->end_element( { Name => $element->[0] } );
}

=head1 SYNOPSIS

    use XML::Struct::Writer;

    my $writer = XML::Struct::Writer->new;
    my $xml = $writer->writeDocument( [
        greet => { }, [
            "Hello, ",
            [ emph => { color => "blue" } , [ "World" ] ],
            "!"
        ]
    ] ); 
    
    $xml->toFile("greet.xml");

=head1 DESCRIPTION

This module transforms an XML document, given in form of a data structure as
described in L<XML::Struct>, into a stream of SAX1 events. By default, the
stream is used to build a L<XML::LibXML::Document> that can be used for
instance to write the XML document to a file.

=head1 WRITING TO HANDLERS

The C<handler> property can be used to specify a SAX handler that XML stream
events are send to. By default L<XML::LibXML::SAX::Builder> is used to build a
DOM that is serialized afterwards. Using another handler should be more
performant for serialization. See L<XML::Writer>, L<XML::Handler::YAWriter>
(and possibly L<XML::SAX::Writer> combined with L<XML::Filter::SAX1toSAX2>) for
stream-based XML writers.

Handlers do not need to support all features of SAX. A handler is expected to
implement the following methods:

=over 4

=item

    start_document()

=item

    start_element( { Name => $name, Attributes => \%attributes } )

=item

    end_element( { Name => $name } )

=item

    characters( { Data => $characters } )

=item 

    end_document()

=back

If the handler further implements a C<result()> method, it is called at the end
of C<writeDocument>.

=cut

1;
