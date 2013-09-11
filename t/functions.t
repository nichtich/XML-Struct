use strict;
use Test::More;
use XML::Struct qw(readXML writeXML simpleXML textValues);

is_deeply simpleXML(["root"]), { }, 'simple empty root';
is_deeply simpleXML(["root",{},["text"]]), { }, 'simple empty root with text';
is_deeply simpleXML(["root",{ x => 1, y => 2 },["text"]]), 
    { x => 1, y => 2 }, 
    'simple empty root with text and attributes';

is_deeply simpleXML([
        root => { x => 1 }, [
            "text",
            [ "x", {}, [2] ]
        ]
    ]), { 
        x => [ 1, 2 ]
    }, 'simple attributes/children';

is_deeply simpleXML([ a => { x => 1 } ], root => 1),
    { a => { x => 1 } }, 
    'simple with KeepRoot (root=1)';    

is_deeply simpleXML([ a => { x => 1 } ], root => 'doc'),
    { doc => { x => 1 } }, 
    'simple with custom root';

is_deeply simpleXML([ a => { x => 1 }, [[ x => {}, ['2'] ]]], root => 'doc'),
    { doc => { x => [1,2] } }, 
    'simple with custom root and attributes/values';

is textValues([
        root => {}, [
            "some ",
            [foo => {}, [
                    [ bar => {}, ["text"]]
                ]
            ]
        ]
    ]), "some text";

my $xml = readXML(<<'XML', simple => 1);
<root>
  <foo>text</foo>
  <bar key="value">
    text
    <doz/>
  </bar>
</root>
XML

is_deeply $xml, {
    foo => "text",
    bar => {
        key => "value",
        doz => {}
    }
}, 'hashified with readXML';

done_testing;
