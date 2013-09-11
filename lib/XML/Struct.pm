package XML::Struct;
# ABSTRACT: Represent XML as data structure preserving element order
# VERSION

use strict;
use XML::LibXML::Reader;
use List::Util qw(first);

use XML::Struct::Reader;
use XML::Struct::Writer;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML writeXML hashifyXML textValues);

sub readXML { # ( [$from], %options )
    my (%options) = @_ % 2 ? (from => @_) : @_;

    my %reader_options = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} } qw(attributes whitespace path stream hashify root)
    );
    if (%options) {
        if (exists $options{from} and keys %options == 1) {
            $reader_options{from} = $options{from};
        } else {
            $reader_options{from} = \%options;
        }
    }

    XML::Struct::Reader->new( %reader_options )->readDocument;
}

sub writeXML {
    my ($xml, %options) = @_;
    XML::Struct::Writer->new(%options)->write($xml); 
}

sub hashifyXML {
    my ($element, %options) = @_;

    my $attributes = (!defined $options{attributes} or $options{attributes});

    if ($options{root}) {
        my $root = $options{root};
        $root = $element->[0] if $root =~ /^[+-]?[0-9]+$/;

        my $hash = $attributes
                ? _hashify(1, [ dummy => {}, [$element] ])
                : _hashify(0, [ dummy => [$element] ]);

        return { $root => values %$hash };
    }

    my $hash = _hashify($attributes, $element);
    $hash = { } unless ref $hash;

    return $hash;
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

# hashifies attributes and child elements
sub _hashify {
    my $with_attributes = shift;
    my ($children, $attributes) = $with_attributes ? ($_[0]->[2], $_[0]->[1]) : ($_[0]->[1]);

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
        _push_hash( $hash, $child->[0] => _hashify($with_attributes, $child) );
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

L<XML::Struct> implements a mapping of "document-oriented" XML to Perl data
structures.  The mapping preserves element order but only XML elements,
attributes, and text nodes (including CDATA-sections) are included. In short,
an XML element is represented as array reference:

   [ $name => \%attributes, \@children ]

To give an example, with L<XML::Struct::Reader>, this XML document:

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

Key-value (aka "data-oriented") XML, as known from L<XML::Simple> can be
created with C<hashifyXML>:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

Both parsing and serializing are fully based on L<XML::LibXML>, so performance
is better than L<XML::Simple> and similar to L<XML::LibXML::Simple>.

=head1 EXPORTED FUNCTIONS

The following functions can be exported on request:

=head2 readXML( [ $source ] , [ %options ] )

Read an XML document with L<XML::Struct::Reader>. The type of source (string,
filename, URL, IO Handle...) is detected automatically.

=head2 writeXML( $xml, %options )

Write an XML document with L<XML::Struct::Writer>.

=head2 hashify( $element [, %options ] )

Transforms an XML element into a flattened hash, similar to what L<XML::Simple>
returns. Attributes and child elements are treated as hash keys with their
content as value. Text elements without attributes are converted to text and
empty elements without attributes are converted to empty hashes.

The option C<root> works similar to C<KeepRoot> in L<XML::Simple>.

Key attributes (C<KeyAttr> in L<XML::Simple>) and the options 
C<ForceArray> are not supported (yet?).

=head1 SEE ALSO

L<XML::Simple>, L<XML::Twig>, L<XML::Fast>, L<XML::GenericJSON>,
L<XML::Structured>, L<XML::Smart>...

=encoding utf8

=cut

1;
