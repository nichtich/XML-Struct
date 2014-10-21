package XML::Struct::Writer;
#ABSTRACT: Write XML data structures to XML streams
our $VERSION = '0.23'; #VERSION

use strict;
use Moo;
use XML::LibXML::SAX::Builder;
use XML::Struct::Writer::Stream;
use Scalar::Util qw(blessed reftype);
use Carp;

has attributes => (is => 'rw', default => sub { 1 });
has encoding   => (is => 'rw', default => sub { 'UTF-8' });
has version    => (is => 'rw', default => sub { '1.0' });
has standalone => (is => 'rw');
has pretty     => (is => 'rw', default => sub { 0 }); # 0|1|2
has xmldecl    => (is => 'rw', default => sub { 1 });
has root       => (is => 'rw', default => sub { 'root' });

has to         => (
    is => 'rw',
    coerce => sub {
        return IO::File->new($_[0], "w") unless ref $_[0];
        if (reftype($_[0]) eq 'SCALAR') {
            open my $io,">:utf8",$_[0]; 
            return $io;
        } else { # IO::Handle, GLOB, ...
            return $_[0];
        }
    }
);

has handler => (
    is => 'rw',
    lazy => 1,
    builder => sub { 
        $_[0]->to ? XML::Struct::Writer::Stream->new(
            fh       => $_[0]->to,
            encoding => $_[0]->encoding,
            version  => $_[0]->version,
            pretty   => $_[0]->pretty,
        ) : XML::LibXML::SAX::Builder->new( handler => $_[0] ); 
    }
);

sub write {
    my $self = shift;

    $self->writeStart;
    $self->writeElement($self->rootElement(@_));
    $self->writeEnd;
    
    $self->handler->can('result') ? $self->handler->result : 1;
}

*writeDocument = \&write;

sub rootElement {
    my ($self, $root, $name) = @_;

    if (my $type = reftype($root)) {
        if ($type eq 'ARRAY') {
            return $root;
        } elsif ($type eq 'HASH') {
            return [
                $name || $self->root, 
                simpleChildElements($root)
            ]
        }
    }

    croak "expected ARRAY or HASH as root element";
}

# convert simple format to MicroXML
sub simpleChildElements {
    my ($simple) = @_;
    [
        map {
            my ($tag, $content) = ($_, $simple->{$_});
            if (!defined $content) {
                ();
            } elsif (!ref($content)) {
                [ $tag, [$content] ]
            } elsif (reftype($content) eq 'ARRAY') {
                @$content
                    ? map { [ $tag, [$_] ] } @$content
                    : [ $tag ]; 
            } elsif (reftype($content) eq 'HASH') {
                [ $tag, {}, $content ];
            } else {
                ();
            }
        } sort keys %$simple
    ]
}

# return child elements as array reference
sub elementChildren {
    my ($self, $element) = @_;

    my $children = $element->[
        !$self->attributes or (reftype($element->[1]) // '') eq 'ARRAY'
        ? 1 : 2
    ] // [ ];
 
    my $type = reftype($children);
    if (!$type) {
        [ $children ] # simple character content
    } elsif( $type eq 'ARRAY' ) {
        [
            map { 
                (reftype($_) // '') eq 'HASH' ? @{ simpleChildElements($_) } : $_ 
            } @$children
        ]
    } elsif( $type eq 'HASH' ) {
        simpleChildElements($children)
    } else {
        croak "expected ARRAY or HASH as child elements";
    }
}

sub writeElement {
    my $self = shift;
    
    foreach my $element (@_) {
        $self->writeStartElement($element);

        my $children = $self->elementChildren($element);
        foreach my $child ( @$children ) {
            if (ref $child) {
                $self->writeElement($child);
            } else {
                $self->writeCharacters($child);
            }
        }

        $self->writeEndElement($element);
    }
}

sub writeStartElement {
    my ($self, $element) = @_;

    my $args = { Name => $element->[0] };

    if ($self->attributes) {
        my $type = reftype($element->[1]);
        if (defined $type and $type eq 'HASH') {
            $args->{Attributes} = $element->[1];
        }
    }

    $self->handler->start_element($args); 
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
    if ($self->handler->can('xml_decl') && $self->xmldecl) {
        $self->handler->xml_decl({
            Version => $self->version, 
            Encoding => $self->encoding,
            Standalone => $self->standalone,
        });
    }
    $self->writeStartElement( $self->rootElement(@_) ) if @_;
}

sub writeEnd {
    my $self = shift;
    $self->writeEndElement($_[0]) if @_;
    $self->handler->end_document;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

XML::Struct::Writer - Write XML data structures to XML streams

=head1 VERSION

version 0.23

=head1 SYNOPSIS

    use XML::Struct::Writer;

    # create DOM
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

    # serialize
    XML::Struct::Writer->new(
        attributes => 0,
        pretty => 1,
        to => \*STDOUT,
    )->write( [
        doc => [ 
            [ name => [ "alice" ] ],
            [ name => [ "bob" ] ],
        ] 
    ] );

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

=head1 METHODS

=head2 write( $root [, $name ] ) == writeDocument( $root [, $name ] )

Write an XML document, given in form of its root element as array reference
(MicroXML) or in simple format as hash reference with an optional root element
name (simpleXML). The handler's C<result> method, if implemented, is used to
get a return value.

For most applications this is the only method one needs to care about. If the
XML document to be written is not fully given as root element, one has to
directly call the following methods. This method is basically equivalent to:

    $writer->writeStart;
    $writer->writeElement($root);
    $writer->writeEnd;
    $writer->result if $writer->can('result');

=head2 writeStart( [ $root [, $name ] ] )

Call the handler's C<start_document> and C<xml_decl> methods. An optional root
element can be passed, so C<< $writer->writeStart($root) >> is equivalent to:

    $writer->writeStart;
    $writer->writeStartElement($root);

=head2 writeElement( $element [, @more_elements ] )

Write one or more XML elements, including their child elements, to the handler.

=head2 writeStartElement( $element )

Directly call the handler's C<start_element> method.

=head2 writeEndElement( $element )

Directly call the handler's C<end_element> method.

=head2 writeCharacters( $string )

Directy call the handler's C<characters> method.

=head2 writeEnd( [ $root ] )

Directly call the handler's C<end_document> method. An optional root element
can be passed, so C<< $writer->writeEnd($root) >> is equivalent to:

    $writer->writeEndElement($root);
    $writer->writeEnd;

=head1 CONFIGURATION

=over

=item attributes

Set to true by default to expect attribute hashes in the L<XML::Struct> input
format. If set to false, XML elements must be passed as

    [ $name => \@children ]

instead of

    [ $name => \%attributes, \@children ]

Do B<not> set this to false when serializing simple xml in form of hashes!

=item encoding

Sets the encoding for handlers that support an explicit encoding. Set to UTF-8
by default.

=item version

Sets the XML version (C<1.0> by default).

=item xmldecl

Include XML declaration on serialization. Enabled by default.

=item standalone

Add standalone flag in the XML declaration.

=item to

Filename, L<IO::Handle>, or other kind of stream to serialize XML to.

=item handler

Specify a SAX handler that L</"SAX EVENTS"> are send to. Automatically set to
an instance of L<XML::Struct::Writer::Stream> if option C<to> has been
specified or to an instance of L<XML::LibXML::SAX::Builder> otherwise.

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

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
