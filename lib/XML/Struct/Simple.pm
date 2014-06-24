package XML::Struct::Simple;
# ABSTRACT: Transform MicroXML data structures into simple (unordered) form
# VERSION

use strict;
use Moo;
use List::Util qw(first);

has root       => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });
has depth      => (is => 'rw');

sub transform {
    my ($self, $element) = @_;

    my $attributes = (!defined $self->attributes or $self->attributes);

    if ($attributes eq 'remove') {
        $element = removeXMLAttr($element);
        $attributes = 0;
    }

    if (defined $self->depth and $self->depth !~ /^\+?\d+/) {
        $self->depth(undef);
    }

    if ($self->root) {
        my $root = $self->root;
        $root = $element->[0] if $root =~ /^[+-]?[0-9]+$/;

        $self->depth($self->depth - 1) if defined $self->depth;

        my $hash = $attributes
                ? _simple(1, [ dummy => {}, [$element] ], $self->depth)
                : _simple(0, [ dummy => [$element] ], $self->depth);

        return { $root => values %$hash };
    }

    my $hash = _simple($attributes, $element, $self->depth);
    $hash = { } unless ref $hash;

    return $hash;
}

sub removeXMLAttr {
    my $node = shift;
    ref $node
        ? ( $node->[2]
            ? [ $node->[0], [ map { removeXMLAttr($_) } @{$node->[2]} ] ]
            : [ $node->[0] ] ) # empty element
        : $node;               # text node
}

# hashifies attributes and child elements
sub _simple {
    my $with_attributes = shift;
    my ($children, $attributes) = $with_attributes ? ($_[0]->[2], $_[0]->[1]) : ($_[0]->[1]);
    my $depth = defined $_[1] ? $_[1] - 1 : undef;

    # empty element or characters only 
    if (!($attributes and %$attributes) and !first { ref $_ } @$children) {
        my $text = join "", @$children;
        return $text ne "" ? $text : { };
    }

    my $hash = { $attributes ? %$attributes : () };

    foreach my $child ( @$children ) {
        next unless ref $child; # skip mixed content text
        if (defined $depth and $depth < 0) {
            _push_hash( $hash, $child->[0], $child, 1 );
        } else {
            _push_hash( $hash, $child->[0] => _simple($with_attributes, $child, $depth) );
        }
    }

    return $hash; 
}

sub _push_hash {
    my ($hash, $key, $value, $force) = @_;

    if ( exists $hash->{$key} ) {
        if ((ref $hash->{$key} || '') ne 'ARRAY') {
            $hash->{$key} = [ $hash->{$key} ];
        }
        push @{$hash->{$key}}, $value;
    } elsif ( $force ) {
        $hash->{$key} = [ $value ];
    } else {
        $hash->{$key} = $value;
    }
}

=head1 SYNOPSIS

    my $converter = XML::Struct::Simple->new( root => 'record' );
    my $struct = [ root => { xmlns => 'http://example.org/' }, 
                   [ '!', [ x => {}, [42] ] ] ];

    my $simple = $converter->transform( $xml );
    # { record => { xmlns => 'http://example.org/', x => 42 } }

=head1 DESCRIPTION

This module implements a transformation from structured XML (MicroXML) to
simple key-value format as known from L<XML::Simple>: Attributes and child
elements are treated as hash keys with their content as value. Text elements
without attributes are converted to text and empty elements without attributes
are converted to empty hashes.

L<XML::Struct> can export the function C<simpleXML> for easy use.

=head1 CONFIGURATION

=over

=item root

Keep the root element (just as option C<KeepRoot> in L<XML::Simple>). In
addition one can set the name of the root element if a non-numeric value is
passed.

=item depth

Only transform to a given depth. See L<XML::Struct::Reader> for documentation.

All elements below the given depth are returned unmodified (not cloned) as
array elements:

    $data = simpleXML($xml, depth => 2)
    $content = $data->{x}->{y}; # array or scalar (if existing)

=item attributes

Assume input without attributes if set to a true value. The special value
C<remove> will first remove attributes, so the following three are equivalent:

    my @children = (['a'],['b']);

    simpleXML( [ $name => \@children ], attributes => 0 );
    simpleXML( removeXMLAttr( [ $name => \%attributes, \@children ] ), attributes => 0 );
    simpleXML( [ $name => \%attributes, \@children ], attributes => 'remove' );

=back

Key attributes (C<KeyAttr> in L<XML::Simple>) and the option C<ForceArray> are
not supported yet.

=encoding utf8

=cut

1;
