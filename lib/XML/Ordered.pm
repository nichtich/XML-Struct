package XML::Ordered;
# ABSTRACT: Convert document-oriented XML to data structures, preserving element order
# VERSION

use XML::LibXML::Reader;
use XML::Ordered::Reader;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(readXML);

sub readXML {
    my ($input, %options) = @_;
    
    my %reader_options = (
        map { $_ => delete $options{$_} }
        grep { exists $options{$_} } qw(attributes whitespace)
    );

    if (!defined $input or $input eq '-') {
        $options{IO} = \*STDIN
    } elsif( $input =~ /^</ ) {
        $options{string} = $input;
    } elsif( ref $input and ref $input eq 'SCALAR' ) {
        $options{string} = $$input;
    } elsif( ref $input ) { # TODO: support IO::Handle?
        $options{IO} = $input;
    } else {
        $options{location} = $input; # filename or URL
    }

    # options include 'recover' etc.
    my $reader = XML::LibXML::Reader->new( %options );

    my $r = XML::Ordered::Reader->new( %reader_options );
    return $r->read($reader);

}

=head1 SYNOPSIS

    use XML::Ordered;

    ...

=head1 DESCRIPTION

This module implements a mapping of document-oriented XML to Perl data
structures.  The mapping preserves element order but XML comments,
processing-instructions, unparsed entities etc. are ignored, similar
to L<XML::Simple>. With L<XML::Ordered::Reader>, this XML document:

    <root>
      <foo>text</foo>
      <bar key="value">
        text
        <doz/>
      </bar>
    </root>

is transformed to this structure:

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

L<XML::Simple>, L<XML::Fast>, L<XML::GenericJSON>, L<XML::Structured>,
L<XML::Smart>

=encoding utf8

=cut

1;
