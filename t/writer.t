use strict;
use Test::More;
use XML::Struct::Writer;
use Encode;

my $writer = XML::Struct::Writer->new;
my $xml = $writer->writeDocument( [
    greet => { }, [
        "Hello, ",
        [ emph => { color => "blue" } , [ "World" ] ],
        "!"
    ]
] );
isa_ok $xml, 'XML::LibXML::Document';
is $xml->serialize, <<'XML', 'writeDocument';
<?xml version="1.0"?>
<greet>Hello, <emph color="blue">World</emph>!</greet>
XML

$xml = $writer->writeDocument( [ doc => { a => 1 }, [ "\x{2603}" ] ] );
$xml->setEncoding("UTF-8");
is $xml->serialize,
    encode("UTF-8", <<XML), "UTF-8";
<?xml version="1.0" encoding="UTF-8"?>
<doc a="1">\x{2603}</doc>
XML

## TODO: Write an XML fragment
#$xml = $writer->writeElement(
#    [ "foo", { x => 1 }, [ ["bar"], "text" ] ]
#);
# is $xml->serialize, "<foo x=\"1\"><bar/>text</foo>",

# TODO: Test writing to a handler

done_testing;
