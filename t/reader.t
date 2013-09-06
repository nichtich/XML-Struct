use strict;
use Test::More;
use XML::Ordered qw(readXML);

my ($data, $reader, $stream);

$stream = XML::LibXML::Reader->new( string => "<root> </root>" );
$reader = XML::Ordered::Reader->new;
is_deeply $reader->read( $stream ), [ 'root' ], 'skip whitespace';

$stream = XML::LibXML::Reader->new( string => "<root> </root>" );
$reader = XML::Ordered::Reader->new( whitespace => 1 );
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


my $xml = <<'XML';
<nested>
  <items>
    <a>X</a>
    <b/>
    <a>Y</a>
  </items>
</nested>
XML

$stream = XML::LibXML::Reader->new( string => $xml );
$reader = XML::Ordered::Reader->new( attributes => 0 );
$data = $reader->read( $stream );
is_deeply $data, 
    [ nested => [
      [ items => [
        [ a => ["X"] ],
        [ "b" ],
        [ a => ["Y"] ], 
      ] ]
    ] ], 'without attributes';

$stream = XML::LibXML::Reader->new( string => $xml );
$reader = XML::Ordered::Reader->new( attributes => 0 );

$data = $reader->readNext( $stream, 'nested/items/*' );
is_deeply $data, [ a => ["X"] ], 'readNext (relative)';
$data = $reader->readNext( $stream, '/nested/items/*' );
is_deeply $data, [ "b" ], 'readNext (absolute)';
$data = $reader->readNext( $stream, '*' );
is_deeply $data, [ a => ["Y"] ], 'readNext (relative)';

$stream = XML::LibXML::Reader->new( string => $xml );
$reader = XML::Ordered::Reader->new( attributes => 0 );

$data = $reader->readNext( $stream, 'nested/items/b' );
is_deeply $data, [ "b" ], 'readNext (with name)';

# use Data::Dumper; print STDERR Dumper($data);

done_testing;
