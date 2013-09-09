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
}, 'hashified';

done_testing;
