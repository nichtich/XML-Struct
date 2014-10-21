package XML::Struct::Simple;
# ABSTRACT: Transform MicroXML data structures into simple (unordered) form
our $VERSION = '0.23'; # VERSION

use strict;
use Moo;
use List::Util qw(first);

has root       => (is => 'rw', default => sub { 0 });
has attributes => (is => 'rw', default => sub { 1 });
has content    => (is => 'rw', default => sub { 'content' });
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
                ? $self->_simple(1, [ dummy => {}, [$element] ], $self->depth)
                : $self->_simple(0, [ dummy => [$element] ], $self->depth);

        return { $root => values %$hash };
    }

    my $hash = $self->_simple($attributes, $element, $self->depth);
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
    my $self = shift;
    my $with_attributes = $_[0];
    my ($children, $attributes) = $with_attributes ? ($_[1]->[2], $_[1]->[1]) : ($_[1]->[1]);
    my $depth = defined $_[2] ? $_[2] - 1 : undef;

    my $text_only = (first { ref $_ } @$children) ? undef : join("",@$children);

    # empty element or characters only 
    if (!($attributes and %$attributes) and defined $text_only) {
        return $text_only ne "" ? $text_only : { };
    }

    my $hash = { $attributes ? %$attributes : () };
    $hash->{ $self->content } = $text_only if defined $text_only and @$children;

    foreach my $child ( @$children ) {
        next unless ref $child; # skip mixed content text
        if (defined $depth and $depth < 0) {
            _push_hash( $hash, $child->[0], $child, 1 );
        } else {
            _push_hash( $hash, $child->[0] => $self->_simple($with_attributes, $child, $depth) );
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


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

XML::Struct::Simple - Transform MicroXML data structures into simple (unordered) form

=head1 VERSION

version 0.23

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

Keep the root element instead of removing. This corresponds to option
C<KeepRoot> in L<XML::Simple>. In addition one can set the name of the root
element if a non-numeric value is passed.

=item content

With option C<simple> enable, text content at elements with attributes is
parsed into a hash value with this key.  Set to "C<content> by default.
Corresponds to option C<ContentKey> in L<XML::Simple>.

=item attributes

Assume input without attributes if set to a true value. The special value
C<remove> will first remove attributes, so the following three are equivalent:

    my @children = (['a'],['b']);

    simpleXML( [ $name => \@children ], attributes => 0 );
    simpleXML( removeXMLAttr( [ $name => \%attributes, \@children ] ), attributes => 0 );
    simpleXML( [ $name => \%attributes, \@children ], attributes => 'remove' );

=back

Option C<KeyAttr>, C<ForceArray>, and other fetures of L<XML::Simple> not
supported (yet).

=head1 AUTHOR

Jakob Voß

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
