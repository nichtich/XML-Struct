use strict;
use Test::More;
use XML::Struct qw(readXML);

my ($data, $reader, $stream);

$stream = XML::LibXML::Reader->new( string => "<root> </root>" );
$reader = XML::Struct::Reader->new;
is_deeply $reader->read( $stream ), [ 'root' ], 'skip whitespace';

$stream = XML::LibXML::Reader->new( string => "<root> </root>" );
$reader = XML::Struct::Reader->new( whitespace => 1 );
is_deeply $reader->read( $stream ), [ 'root' => { }, [' '] ], 'whitespace';

$data = readXML(<<'XML');
<root x:a="A" a="B" xmlns:x="http://example.org/">
  <foo>t&#x65;xt</foo>
  <bar key="value">
    text
    <doz/><![CDATA[xx]]></bar>
</root>
XML

is_deeply $data, [
      'root', {
        'a' => 'B',
        'xmlns:x' => 'http://example.org/',
        'x:a' => 'A'
      }, [
        [
          'foo', { },
          [ 'text' ]
        ],
        [
          'bar', { 'key' => 'value' },
          [
            "\n    text\n    ",
            [ 'doz' ],
            "xx"
          ]
        ]
      ]
    ], 'readXML';

is_deeply readXML( 't/nested.xml', attributes => 0 ), 
    [ nested => [
      [ items => [ [ a => ["X"] ] ] ],
      [ "foo" => [ [ "bar" ] ] ],
      [ items => [
        [ "b" ],
        [ a => ["Y"] ], 
      ] ]
    ] ], 'without attributes';

my $xml = <<'XML';
<!DOCTYPE doc [
    <!ELEMENT doc EMPTY>
    <!ATTLIST doc attr CDATA "42">
]><doc/>
XML

is_deeply readXML( $xml, complete_attributes => 1, hashify => 1 ),
    { attr => 42 }, 'mixed attributes';
is_deeply readXML( $xml, complete_attributes => 0, hashify => 1, root => 1 ),
    { doc => { } }, 'mixed attributes';

done_testing;
