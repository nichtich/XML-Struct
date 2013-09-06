package XML::Ordered;
# ABSTRACT: Convert document-oriented XML to data structures, preserving element order
# VERSION

use XML::LibXML::Reader;
use XML::Ordered::Reader;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML);

sub readXML {
    my ($input, %options) = @_;
    
    # options include 'recover' etc.
    my $reader = XML::LibXML::Reader->new( string => $input, %options );
    # from string, filename, GLOB, IO::Handle...

    my $r = XML::Ordered::Reader->new( %options );
    return $r->read($reader);

}

=head1 SYNOPSIS

...

=head1 DESCRIPTION

This module implements a mapping of XML to Perl data structures for
document-oriented XML. The mapping preserves element order but XML comments,
processing-instructions, unparsed entities etc. are ignored.

    <root>
      <foo>text</foo>
      <bar key="value">
        text
        <doz/>
      </bar>
    </root>

is transformed to

    [
      "root", { }, [
        [ "foo", { }, "text" ],
        [ "bar", { key => "value" }, [
          "text", 
          [ "doz", { } ]
        ] 
      ]
    ]

=head1 SEE ALSO

L<XML::Simple>, L<XML::Fast>, L<XML::GenericJSON>, L<XML::Structured>

=encoding utf8

=cut

1;
