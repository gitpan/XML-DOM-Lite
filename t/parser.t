use lib 'lib';

use Test::More tests => 15;

use XML::DOM::Lite qw(Parser :constants);

my $xmlstr = <<XML;
<root>
  <item1 attr1="val1" attr2="val2">text</item1>
  <item2 id="item2id">
    <item3 instance="0"/>
    <item4>
      deep text 1
      <item5>before</item5>
      deep text 2
      <item6>after</item6>
      deep text 3
    </item4>
    <item3 instance="1"/>
  </item2>
  some more text
</root>
XML

my $parser = Parser->new;
ok($parser);

my $doc = Parser->parse($xmlstr);
ok($doc);

ok($doc->nodeType & DOCUMENT_NODE);
ok($doc->documentElement);
ok($doc->documentElement->tagName eq "root");
ok($doc->documentElement->nodeType & ELEMENT_NODE);

my $item3s = $doc->getElementsByTagName('item3');
ok($item3s);

ok($item3s->isa('XML::DOM::Lite::NodeList'));
ok(scalar(@$item3s) eq 2);
ok(my $item2 = $doc->getElementById("item2id"));
ok($item2->getAttribute("id") eq "item2id");
ok($item2->tagName eq "item2");
ok($doc->documentElement->firstChild->tagName eq "item1");
ok($doc->documentElement->lastChild->nodeType & TEXT_NODE);
ok($doc->documentElement->lastChild->nodeValue eq "  some more text\n");
