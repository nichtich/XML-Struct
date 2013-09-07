use strict;
use Test::More;
use XML::Ordered::Writer;
use XML::LibXML::SAX::Builder;

sub check_write(@) { # TODO: support as public method (writeDocumentToString)
    my $options  = shift;
    my $builder = XML::LibXML::SAX::Builder->new;
    my $writer  = XML::Ordered::Writer->new( handler => $builder, %$options );
    $writer->writeDocument(shift);
    is $builder->result->toString, shift, shift;
}

check_write {},
    [ "foo", { x => 1 }, [ ["bar"], "text" ] ] =>
    "<?xml version=\"1.0\"?>\n<foo x=\"1\"><bar/>text</foo>\n";

# default handler
my $writer = XML::Ordered::Writer->new;
my $doc = $writer->writeDocument( [ "root", { a => 1 }, [ "text" ] ] );
isa_ok($doc,'XML::LibXML::Document');
is "$doc", "<?xml version=\"1.0\"?>\n<root a=\"1\">text</root>\n";

#    my $writer  = XML::Ordered::Writer->new;
#use XML::Handler::YAWriter;
#my $handler = new XML::Handler::YAWriter( AsFile => '-' );

#my $writer = XML::Ordered::Writer->new( handler => $handler );
#$writer->writeDocument( [ "foo", { x => 1 } ] );

# is '<?xml version="1.0" encoding="UTF-8"?><foo></foo>'

done_testing;
