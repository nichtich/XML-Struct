package XML::Ordered::Writer;
# ABSTRACT: Process ordered XML as stream, for instance to write XML
# VERSION

use strict;
use Moo;

# Must be a (simplified) SAX1 handler
has handler => (
    is => 'rw',
    default => sub {
        #XML::Ordered::Writer::Document->new( handler => $_[0] );
        XML::LibXML::SAX::Builder->new( handler => $_[0] );
    }
);

sub writeDocument {
    my ($self, $root) = @_;
    $self->handler->start_document;
    $self->writeElement($root);
    $self->handler->end_document;
    return $self->handler->result if $self->handler->can('result');
}

sub writeElement {
    my ($self, $element) = @_;

    my $handler = $self->handler;

    my %args = ( Name => $element->[0] );
    if ($element->[1]) {
        $args{Attributes} = $element->[1];
    }

    $handler->start_element( \%args );

    if ($element->[2]) {
        foreach my $child ( @{$element->[2]} ) {
            if (ref $child) {
                $self->writeElement($child);
            } else {
                $handler->characters({ Data => $child });
            }
        }
    }
    $handler->end_element( \%args );

}

=head1 SYNOPSIS

...

=head1 DESCRIPTION

This module transforms an XML document, given in form of a data structure as
described in L<XML::Ordered>, into a stream of SAX1 events. By default, the
stream is used to build a L<XML::LibXML::Document> that can be used for
instance to write the XML document to a file. Alternatively one can choose to a
(simplified) SAX1 handler (that is an object with the methods
C<start_document>, C<start_element>, C<end_element>, C<characters>, and
C<end_document>) for more elaborated or performant processing.

For instance one can use a stream-based XML writer such as L<XML::Writer>,
L<XML::Handler::YAWriter>, and L<XML::SAX::Writer>, or one can transform
the stream into a SAX2 stream with L<XML::Filter::SAX1toSAX2>.

=head1 SEE ALSO

L<XML::LibXML::SAX::Builder> (to build a DOM from SAX events)

=cut

1;
