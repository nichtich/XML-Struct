use strict;
use Test::More;
use XML::Struct::Writer;
use Encode;

sub write_xml {
    my $str = "";
    my $writer = XML::Struct::Writer->new( to => \$str, xmldecl => 0 );
    $writer->write(@_);
    $str;
}

my $struct = {
    foo => [0],
    bar => [],
    doz => ["Hello","World"],
#    xxx => undef,
};
my $xml = "<greet><bar/><doz>Hello</doz><doz>World</doz><foo>0</foo></greet>\n";

is write_xml($struct, 'greet'), $xml, 'simple format';

$struct = { foo => { bar => { doz => {} } } };
$xml = "<root><foo><bar><doz/></bar></foo></root>\n";
is write_xml($struct), $xml, 'simple format';

$struct = [ micro => {}, { xml => 1 } ];
is write_xml($struct), "<micro><xml>1</xml></micro>\n", "mixed format";

$struct = [ A => [ " ", { B => 1 }, "  ", { B => [] } ] ];
is write_xml($struct), "<A> <B>1</B>  <B/></A>\n", "mixed format";

done_testing;
