package XML::DOM::Lite;

our $VERSION = 0.03;

use XML::DOM::Lite::Constants qw(:all);
use XML::DOM::Lite::Parser;
use XML::DOM::Lite::Document;
use XML::DOM::Lite::Node;
use XML::DOM::Lite::NodeList;
use XML::DOM::Lite::NodeIterator;
use XML::DOM::Lite::NodeFilter;
use XML::DOM::Lite::Serializer;
use XML::DOM::Lite::XPath;

require Exporter;
@ISA = qw(Exporter);

use constant Parser       => 'XML::DOM::Lite::Parser';
use constant Document     => 'XML::DOM::Lite::Document';
use constant Node         => 'XML::DOM::Lite::Node';
use constant NodeList     => 'XML::DOM::Lite::NodeList';
use constant NodeIterator => 'XML::DOM::Lite::NodeIterator';
use constant NodeFilter   => 'XML::DOM::Lite::NodeFilter';
use constant Serializer   => 'XML::DOM::Lite::Serializer';
use constant XPath        => 'XML::DOM::Lite::XPath';

@EXPORT_OK = (
    @XML::DOM::Lite::Constants::EXPORT_OK,
    qw(Parser Document Node NodeList NodeIterator NodeFilter Serializer XPath)
);

%EXPORT_TAGS = ( constants => \@XML::DOM::Lite::Constants::EXPORT_OK );

1;
__END__

=head1 NAME

XML::DOM::Lite - Lite Pure Perl XML DOM Parser Kit 

=head1 SYNOPSIS

 # Parser
 use XML::DOM::Lite qw(Parser :constants);
 
 $parser = Parser->new( %options );
 $doc = Parser->parse($xmlstr);
 $doc = Parser->parseFile('/path/to/file.xml');

 $nlist = $doc->selectNodes('/xpath/expression');
 $node = $doc->selectSingleNode('/xpath/expression');
 
 
 # Document
 $rootnode = $doc->documentElement;
 $nodeWithId = $doc->getElementById("my_node_id");
 $textnode = $doc->createTextNode("some text string");
 $element = $doc->createElement("myTagName");
 $xmlstr = $doc->xml;
 $doc->dispose; # break cyclic refs
 
 
 # All Nodes
 $copy = $node->cloneNode($deep);
 $nodeType = $node->nodeType;
 $parent = $node->parentNode;
 
 
 # Element Nodes
 $last = $node->lastChild;
 $first = $node->firstChild;
 
 $node->setAttribute("foo", $bar);
 $foo = $node->getAttribute("foo");
 
 $liveNodeList = $node->getElementsByTagName("child"); # deep
 
 $node->insertBefore($newchild, $refchild);
 $node->replaceChild($newchild, $refchild);
 
 
 # Text Nodes
 $nodeValue = $node->nodeValue;
 $node->nodeValue("new text value");
 
 
 # NodeList
 $item = $nodeList->item(42);
 $index = $nodeList->nodeIndex($node);
 $nlist->insertNode($newNode, $index);
 $removed = $nlist->removeNode($node);
 $length = $nlist->length; # OR scalar(@$nodeList)
 
 
 # NodeIterator and NodeFilter
 use XML::DOM::Lite qw(NodeIterator NodeFilter :constants);
 
 $nfilt = NodeFilter->new(sub {
     my $n = shift;
     if ($n->tagName eq 'wantme') {
         return FILTER_ACCEPT;
     } elsif ($n->tagName eq 'skipme') {
         return FILTER_SKIP;
     } else {
         return FILTER_REJECT;
     }
 });
 
 $niter = NodeIterator->new($rootnode, SHOW_ELEMENT, $nfilt);
 while (my $n = $niter->nextNode) {
     # do stuff
 }
 
 
 # XPath
 use XML::DOM::Lite qw(XPath);
 
 $xp = XPath->new;
 $nlist = $xp->evaluate('/path/to/*[@attr="value"]', $contextNode);
 
 # Serializer
 use XML::DOM::Lite qw(Serializer);
 
 $serializer = Serializer->new;
 $xmlout = $serializer->serializerToString($node);

=head1 INTRODUCTION

Why Yet Another XML Parser?

Because the DOM standard was not made for Perl and lacks certain
perlisms, and if you, like me, prefer a perlesque way of doing
things, then the full DOM API can get a bit clunky.

Most of the time when dealing with XML DOM trees, I find myself doing
a lot of traversal - and when doing so, I usually want my DOM tree to
be a HASH ref with ARRAY refs of HASH refs (etc.) so that I can say :

 foreach (@{$node->childNodes}) {
     if ($_->nodeType & ELEMENT_NODE) {
         # do stuff
     }
 }

... or ...

 @cdata = map {
     $_->nodeValue if $_->nodeType eq TEXT_NODE
 }, @{$node->childNodes};

... or for attributes :

 foreach (keys %{$node->attributes}) {
     # do something
 }

Furthermore, maybe sometimes I want the value of an attribute to,
temporarily, be something other than a string, so...

 $node->setAttribute("sessionStash", $session->stash);

Sometimes, I may want to Storable::freeze or YAML::Dump or
DBM::Deep::put my DOM tree (or some part of it) without any XS bits
getting in the way.

Other times, I may just not have Expat handy, and I want something
that can munge a bit of XML into a usable data structure and still
perform reasonably well.

Finally, and this is really how/why this module came to be, I may not
feel like going the whole XSLT hog and simply prefer to treat each
node as a subclassable data entity upon which I can call methods to
make it transform itself.

And/Or any combination of the above.

=head1 DESCRIPTION

XML::DOM::Lite is designed to be a reasonably fast, highly portable,
XML parser kit written in pure perl, implementing the DOM standard
quite closely. To keep performance up and footprint down, certain DOM
features are not supported such as comment, DOCTYPE nodes and
processing instructions (these are simply parsed as text
nodes). However, 90-99% of what most end up doing with XML can be done
without these features.

The standard pattern for using the XML::DOM::Lite parser kit is to
 use XML::DOM::Lite qw(Parser :constants);

Available exports are : I<Parser>, I<Node>, I<NodeList>,
I<NodeIterator>, I<NodeFilter>, I<XPath>, I<Document> and the
constants.

This is mostly for convenience, so that you can save your key-strokes
for the fun stuff. Alternatively, to avoid polluting your namespace,
you can simply :
 use XML::DOM::Lite::Parser;
 use XML::DOM::Lite::Constants qw(:all);
 # ... etc

=head2 Bitwise I<nodeType> comparison

All I<nodeType> comparisons are done with the bitwise `&' operator
against the constants exported by XML::DOM::Constants (which is why it
is customary to import the I<:constants> tag) for performance reasons.

=head1 PERFORMANCE

The following table shows some benchmark results on 2 GHz Athlon 64
running in 32 bit mode (okay, it's fairly beefy, but that's what I
have at the moment):

 +---------------------------------------------+
 | elements | text | attributes | total | time |
 +---------------------------------------------+
 |     1000 |  500 |        500 |  2000 | 0.32 |
 |     2000 | 1000 |       1000 |  4000 | 0.69 |
 +---------------------------------------------+

=head1 BUGS

Better error handling.

=head1 ACKNOWLEDGEMENTS

Robert Frank

=head1 AUTHOR

Copyright (C) 2005 Richard Hundt <richard NO SPAM AT protea-systems.com>

=head1 LICENCE

This library is free software and may be used under the same terms as
Perl itself.

=cut

