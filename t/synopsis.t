use strict;
use Test::More;

my $input = join "\n", '<?xml version="1.0" encoding="UTF-8"?>',
    '<root xmlns="http://example.org/">!<x>42</x></root>','';

diag 'SYNOPSIS of XML::Struct';

use XML::Struct qw(readXML writeXML simpleXML removeXMLAttr);

my $xml = readXML( \$input );
is_deeply $xml, [ root => { xmlns => 'http://example.org/' }, [ '!', [x => {}, [42]] ] ];

my $doc = writeXML( $xml );
is_deeply $doc, $input;

my $simple = simpleXML( $xml, root => 'record' );
is_deeply $simple, { record => { xmlns => 'http://example.org/', x => 42 } };

my $xml2 = removeXMLAttr($xml);
is_deeply $xml2, [ root => [ '!', [ x => [42] ] ] ];

diag 'EXAMPLE of XML::Struct::simpleXML';

my $name = 'foo';
my %attributes = ( a => 42 );
my @children = (['a'],['b']);

my $a = simpleXML( [ $name => \@children ], attributes => 0 );
my $b = simpleXML( removeXMLAttr( [ $name => \%attributes, \@children ] ), attributes => 0 );
my $c = simpleXML( [ $name => \%attributes, \@children ], attributes => 'remove' );

is_deeply $a, { a => {}, b => {} };
is_deeply $a, $b;
is_deeply $b, $c;

done_testing;
