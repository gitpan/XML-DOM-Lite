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
	nodeType   => DOCUMENT_NODE,
	childNodes => [ ],
	elements   => { },
    }), $class;
}

sub parentNode { return undef };

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
        tagName => $tagName,
        nodeType => ELEMENT_NODE,
    });
}

sub createTextNode {
    my ($self, $str) = @_;
    return XML::DOM::Lite::Node->new({
        nodeType => TEXT_NODE,
        nodeValue => $str,
    });
}

sub documentElement {
    my $self = shift;
    unless ($self->{documentElement}) {
	foreach (@{$self->childNodes}) {
	    if ($_->nodeType & 1) { #ELEMENT_NODE
		$self->{documentElement} = $_;
		last;
	    }
	}
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

sub dispose {
    $_[0]->decycle(1);
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
 
 # break cyclic refs
 $doc->dispose;

=head1 DESCRIPTION

XML::DOM::Lite::Document objects are returned by the Parser and shouldn't
generally be instantiated explicitly.

=cut

