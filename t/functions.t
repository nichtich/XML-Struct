use strict;
use Test::More;
use XML::Struct qw(readXML writeXML hashifyXML textValues);

is_deeply hashifyXML(["root"]), { }, 'hashify empty root';
is_deeply hashifyXML(["root",{},["text"]]), { }, 'hashify empty root with text';
is_deeply hashifyXML(["root",{ x => 1, y => 2 },["text"]]), 
    { x => 1, y => 2 }, 
    'hashify empty root with text and attributes';

is_deeply hashifyXML([
        root => { x => 1 }, [
            "text",
            [ "x", {}, [2] ]
        ]
    ]), { 
        x => [ 1, 2 ]
    }, 'hashify attributes/children';

is_deeply hashifyXML([ a => { x => 1 } ], root => 1),
    { a => { x => 1 } }, 
    'hashify with KeepRoot (root=1)';    

is_deeply hashifyXML([ a => { x => 1 } ], root => 'doc'),
    { doc => { x => 1 } }, 
    'hashify with custom root';

is_deeply hashifyXML([ a => { x => 1 }, [[ x => {}, ['2'] ]]], root => 'doc'),
    { doc => { x => [1,2] } }, 
    'hashify with custom root and attributes/values';

is textValues([
        root => {}, [
            "some ",
            [foo => {}, [
                    [ bar => {}, ["text"]]
                ]
            ]
        ]
    ]), "some text";

my $xml = readXML(<<'XML', hashify => 1);
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
