package XML::DOM::Lite::Document;

use strict;
use warnings;

use Carp qw (carp croak cluck);

use XML::DOM::Lite::Constants qw(:all);
use XML::DOM::Lite::XPath;

use base qw(XML::DOM::Lite::Node);

sub new {
    my ($class) = @_;
    return bless $class->SUPER::new({
	nodeName   => '#document',
	nodeType   => DOCUMENT_NODE,
	childNodes => [ ],
	elements   => { },
    }), $class;
}

sub parentNode { undef }

sub appendChild {
    my ($self, $node) = @_;
    if (not $self->{documentElement} and ($node->nodeType & ELEMENT_NODE)) {
	$self->{documentElement} = $node;
    }
    return $self->SUPER::appendChild($node);
}

sub setElementById {
    my ($self, $id, $node) = @_;
    $self->{elements}->{$id} = $node;
}

sub getElementById {
    my ($self, $id) = @_;
    return $self->{elements}->{$id} if exists $self->{elements}->{$id};
}

sub createElement {
    my ($self, $tagName) = @_;
    return XML::DOM::Lite::Node->new({
	nodeName => $tagName,
        tagName => $tagName,
        nodeType => ELEMENT_NODE,
    });
}

sub createTextNode {
    my ($self, $str) = @_;
    return XML::DOM::Lite::Node->new({
	nodeName => '#text',
        nodeType => TEXT_NODE,
        nodeValue => $str,
    });
}

sub documentElement {
    my $self = shift;
    if (@_) {
	$self->{documentElement} = shift;
    }
    $self->{documentElement};
}

sub selectNodes {
    my ($self, $path) = @_;
    return $self->XPathParser->evaluate($path, $self);
}

sub selectSingleNode {
    my ($self, $path) = @_;
    return $self->selectNodes($path)->[0];
}

sub XPathParser {
    my ($self) = @_;
    unless (defined ($self->{XPathParser})) {
	$self->{XPathParser} = XML::DOM::Lite::XPath->new;
    }
    return $self->{XPathParser};
}

sub elements {
    return $_[0]->{elements};
}

sub xml {
    my $self = shift;
    my $serializer = XML::DOM::Lite::Serializer->new;
    return $serializer->serializeToString($self->documentElement);
}

1;
__END__

=head1 NAME

Document - XML DOM Lite Document 

=head1 SYNOPSIS

 $root = $doc->documentElement;
 $node = $doc->getElementById("myid");
 
 # Node creation
 $element = $doc->createElement("tagname");
 $textnode = $doc->createTextNode("some text");
 
 # XPath
 $nlist = $doc->selectNodes("/xpath/expression");
 $node = $doc->selectSingleNode("/xpath/expression");
 
=head1 DESCRIPTION

XML::DOM::Lite::Document objects are returned by the Parser and shouldn't
generally be instantiated explicitly.

=cut
