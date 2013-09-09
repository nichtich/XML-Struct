package XML::Struct;
# ABSTRACT: Convert document-oriented XML to data structures, preserving element order
# VERSION

use strict;
use XML::LibXML::Reader;
use List::Util qw(first);

use XML::Struct::Reader;
use XML::Struct::Writer;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML writeXML hashifyXML textValues);

sub readXML {
    my ($input, %options) = @_;
    
    my $hashify = delete $options{hashify};
    my %reader_options = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} } qw(attributes whitespace)
    );

    if (!defined $input or $input eq '-') {
        $options{IO} = \*STDIN
    } elsif( $input =~ /^</ ) {
        $options{string} = $input;
    } elsif( ref $input and ref $input eq 'SCALAR' ) {
        $options{string} = $$input;
    } elsif( ref $input ) { # TODO: support IO::Handle AND GLOB?
        $options{IO} = $input;
    } else {
        $options{location} = $input; # filename or URL
    }

    # options include 'recover' etc.
    my $reader = XML::LibXML::Reader->new( %options );

    my $r = XML::Struct::Reader->new( %reader_options );
    if ($hashify) {
        return hashifyXML($r->read($reader));
    } else {
        return $r->read($reader);
    }

}

sub writeXML {
    my ($xml, %options) = @_;
    XML::Struct::Writer->new(%options)->write($xml); 
}

sub hashifyXML {
    my $hash = _hashify($_[0]);
    return ref $hash ? $hash : { };
}

sub _push_hash {
    my ($hash, $key, $value) = @_;

    if ( exists $hash->{$key} ) {
        $hash->{$key} = [ $hash->{$key} ] if !ref $hash->{$key};
        push @{$hash->{$key}}, $value;
    } else {
        $hash->{$key} = $value;
    }
}

sub _hashify {
    my $element = shift;

    my ($children, $attributes) = ($element->[2], $element->[1]);

    # empty element or characters only 
    if (!($attributes and %$attributes) and !first { ref $_ } @$children) {
        my $text = join "", @$children;
        return $text ne "" ? $text : { };
    }

    my $hash = { };

    foreach my $key ( keys  %$attributes ) {
        _push_hash( $hash, $key => $attributes->{$key} );
    }            

    foreach my $child ( @$children ) {
        next unless ref $child; # skip mixed content text
        _push_hash( $hash, $child->[0] => _hashify($child) );
    }

    return $hash; 
}

# TODO: document (better name?)
sub textValues {
    my ($element, $options) = @_;
    # TODO: %options (e.g. join => " ")

    my $children = $element->[2];
    return "" if !$children;

    return join "", grep { $_ ne "" } map {
        ref $_ ?  textValues($_, $options) : $_
    } @$children;
}

=head1 SYNOPSIS

    use XML::Struct qw(readXML writeXML hashifyXML);

    my $struct = readXML( "input.xml" );

    my $dom = writeXML( $struct );

    ...

=head1 DESCRIPTION

This module implements a mapping of document-oriented XML to Perl data
structures.  The mapping preserves element order but XML comments,
processing-instructions, unparsed entities etc. are ignored, similar
to L<XML::Simple>. With L<XML::Struct::Reader>, this XML document:

    <root>
      <foo>text</foo>
      <bar key="value">
        text
        <doz/>
      </bar>
    </root>

is transformed to this structure:

    [
      "root", { }, [
        [ "foo", { }, "text" ],
        [ "bar", { key => "value" }, [
          "text", 
          [ "doz", { } ]
        ] 
      ]
    ]

The reverse transformation can be applied with L<XML::Struct::Writer>.

Key-value (aka "data-oriented") XML, can be created with C<hashifyXML>:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

=head1 EXPORTED FUNCTIONS

The following functions can be exported on request:

=head2 readXML( $source, %options )

Read an XML document with L<XML::Struct::Reader>. The type of source (string,
filename, URL, IO Handle...) is detected automatically.

=head2 writeXML( $xml, %options )

Write an XML document with L<XML::Struct::Writer>.

=head2 hashify( $element )

Transforms an XML element into a flattened hash, similar to what L<XML::Simple>
returns. Attributes and child elements are treated as hash keys with their
content as value. Text elements without attributes are converted to text and
empty elements without attributes are converted to empty hashes.

Key attributes (C<KeyAttr> in L<XML::Simple>) and the options C<KeepRoot> and
C<ForceArray> are not supported (yet?).

=head1 SEE ALSO

L<XML::Simple>, L<XML::Fast>, L<XML::GenericJSON>, L<XML::Structured>,
L<XML::Smart>

=encoding utf8

=cut

1;
