# NAME

XML-Struct - Represent XML as data structure preserving element order

# Status

[![Build Status](https://travis-ci.org/nichtich/XML-Struct.svg)](https://travis-ci.org/nichtich/XML-Struct)
[![Coverage Status](https://coveralls.io/repos/nichtich/XML-Struct/badge.svg)](https://coveralls.io/r/nichtich/XML-Struct)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/XML-Struct.png)](http://cpants.cpanauthors.org/dist/XML-Struct)

# SYNOPSIS

    use XML::Struct qw(readXML writeXML simpleXML);

    my $xml = readXML( "input.xml" );
    # [ root => { xmlns => 'http://example.org/' }, [ '!', [ x => {}, [42] ] ] ]

    my $doc = writeXML( $xml );
    # <?xml version="1.0" encoding="UTF-8"?>
    # <root xmlns="http://example.org/">!<x>42</x></root>

    my $simple = simpleXML( $xml, root => 'record' );
    # { record => { xmlns => 'http://example.org/', x => 42 } }

# DESCRIPTION

[XML::Struct](https://metacpan.org/pod/XML::Struct) implements a mapping between XML and Perl data structures. By
default, the mapping preserves element order, so it also suits for
"document-oriented" XML.  In short, an XML element is represented as array
reference with three parts:

    [ $name => \%attributes, \@children ]

This data structure corresponds to the abstract data model of
[MicroXML](http://www.w3.org/community/microxml/), a simplified subset of XML.

If your XML documents don't contain relevant attributes, you can also choose
to map to this format:

    [ $name => \@children ]   # element without attributes
    [ $name ]                 # empty tag without attributes

Both parsing (with [XML::Struct::Reader](https://metacpan.org/pod/XML::Struct::Reader) or function `readXML`) and
serializing (with [XML::Struct::Writer](https://metacpan.org/pod/XML::Struct::Writer) or function `writeXML`) are fully
based on [XML::LibXML](https://metacpan.org/pod/XML::LibXML), so performance is better than [XML::Simple](https://metacpan.org/pod/XML::Simple) and
similar to [XML::LibXML::Simple](https://metacpan.org/pod/XML::LibXML::Simple).

# MODULES

- [XML::Struct::Reader](https://metacpan.org/pod/XML::Struct::Reader)

    Parse XML as stream into XML data structures.

- [XML::Struct::Writer](https://metacpan.org/pod/XML::Struct::Writer)

    Write XML data structures to XML streams for serializing, SAX processing, or
    creating a DOM object.

- [XML::Struct::Writer::Stream](https://metacpan.org/pod/XML::Struct::Writer::Stream)

    Simplified SAX handler for XML serialization.

- [XML::Struct::Simple](https://metacpan.org/pod/XML::Struct::Simple)

    Transform XML data structure into simple form. 

# FUNCTIONS

The following functions are exported on request:

## readXML( $source \[, %options \] )

Read an XML document with [XML::Struct::Reader](https://metacpan.org/pod/XML::Struct::Reader). The type of source (string,
filename, URL, IO Handle...) is detected automatically. See
[XML::Struct::Reader](https://metacpan.org/pod/XML::Struct::Reader) for options. Options not known to XML::Struct::Reader
are passed to [XML::LibXML::Reader](https://metacpan.org/pod/XML::LibXML::Reader).

## writeXML( $xml \[, %options \] )

Write an XML document/element with [XML::Struct::Writer](https://metacpan.org/pod/XML::Struct::Writer). See
[XML::Struct::Writer](https://metacpan.org/pod/XML::Struct::Writer) for options.

## simpleXML( $element \[, %options \] )

Transform an XML document/element into simple key-value format as known from
[XML::Simple](https://metacpan.org/pod/XML::Simple). See [XML::Struct::Simple](https://metacpan.org/pod/XML::Struct::Simple) for options.

## removeXMLAttr( $element )

Transform XML structure with attributes to XML structure without attributes.
The function does not modify the passed element but creates a modified copy.

_this function is deprecated and will be removed in a future release!_

# EXAMPLE

To give an example, with [XML::Struct::Reader](https://metacpan.org/pod/XML::Struct::Reader), this XML document:

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
          [ "doz", { }, [ ] ]
        ] 
      ]
    ]

This module also supports a simple key-value (aka "data-oriented") format, as
used by [XML::Simple](https://metacpan.org/pod/XML::Simple). With option `simple` (or function `simpleXML`) the
document given above would be transformed to this structure:

    {
        foo => "text",
        bar => {
            key => "value",
            doz => {}
        }
    }

# SEE ALSO

This module was first created to be used in [Catmandu::XML](https://metacpan.org/pod/Catmandu::XML) and turned out to
also become a replacement for [XML::Simple](https://metacpan.org/pod/XML::Simple). See the former for more XML
processing.

[XML::Twig](https://metacpan.org/pod/XML::Twig) is another popular and powerfull module for stream-based
processing of XML documents.

See [XML::Smart](https://metacpan.org/pod/XML::Smart), [XML::Hash::LX](https://metacpan.org/pod/XML::Hash::LX), [XML::Parser::Style::ETree](https://metacpan.org/pod/XML::Parser::Style::ETree),
[XML::Fast](https://metacpan.org/pod/XML::Fast), and [XML::Structured](https://metacpan.org/pod/XML::Structured) for different representations of XML data
as data structures (feel free to implement converters from/to XML::Struct).
[XML::GenericJSON](https://metacpan.org/pod/XML::GenericJSON) seems to be an outdated and incomplete attempt to capture
more parts of XML Infoset in another data structure.

See JSONx for a kind of reverse direction (JSON in XML).

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Jakob Voß.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
