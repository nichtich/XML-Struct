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
<?xml version="1.0" encoding="UTF-8"?>
<greet>Hello, <emph color="blue">World</emph>!</greet>
XML

$xml = $writer->writeDocument( [ doc => { a => 1 }, [ "\x{2603}" ] ] );
is $xml->serialize,
    encode("UTF-8", <<XML), "UTF-8";
<?xml version="1.0" encoding="UTF-8"?>
<doc a="1">\x{2603}</doc>
XML

$writer->attributes(0);
$xml = $writer->writeDocument( [
    doc => [ 
        [ name => [ "alice" ] ],
        [ name => [ "bob" ] ],
    ] 
] );
is $xml->serialize(1), <<XML, "indented, without attributes";
<?xml version="1.0" encoding="UTF-8"?>
<doc>
  <name>alice</name>
  <name>bob</name>
</doc>
XML

{
    package MyHandler;
    use Moo;
    has buf => (is => 'rw', default => sub { [ ] });
    sub start_document { push @{$_[0]->buf}, "start" }
    sub start_element {  push @{$_[0]->buf}, $_[1] }
    sub end_element {  push @{$_[0]->buf}, $_[1] }
    sub characters { push @{$_[0]->buf}, $_[1] }
    sub end_document { push @{$_[0]->buf}, "end"}
    sub result { $_[0]->buf }
}

$writer = XML::Struct::Writer->new( handler => MyHandler->new );
$xml = $writer->write( [ "foo", { x => 1 }, [ ["bar"], "text" ] ] );
is_deeply $xml, [
    "start",
    { Name => "foo", Attributes => { x => 1 } },
    { Name => "bar" },
    { Name => "bar" },
    { Data => "text" },
    { Name => "foo" },
    "end"
], 'custom handler';

done_testing;
