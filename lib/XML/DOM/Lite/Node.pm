package XML::DOM::Lite::Node;

use XML::DOM::Lite::NodeList;
use XML::DOM::Lite::Constants qw(:all);

sub new {
    my ($class, $proto) = @_;
    unless (UNIVERSAL::isa($proto->{childNodes}, 'XML::DOM::Lite::NodeList')) {
	$proto->{childNodes} = XML::DOM::Lite::NodeList->new(
            $proto->{childNodes} || [ ]
        );
    }
    $proto->{attributes} = { } unless defined $proto->{attributes};

    my $self = bless $proto, $class;
    return $self;
}

sub childNodes {
    my $self = shift; $self->{childNodes} = shift if @_;
    return $self->{childNodes};
}

sub parentNode {
    my $self = shift;
    if (@_) {
	$self->_setParentNode(@_);
    } else {
	return $self->_getParentNode();
    }
}

sub documentElement {
    $_[0]->{documentElement} = $_[1] if $_[1]; $_[0]->{documentElement};
}

sub _setParentNode {
    my ($self, $parentNode) = @_;
    $self->{parentNode} = $parentNode;
}

sub _getParentNode {
    my ($self) = @_;
    return $self->{parentNode};
}

sub nodeType {
    my $self = shift; $self->{nodeType} = shift if @_;
    $self->{nodeType};
}

sub tagName {
    my $self = shift; $self->{tagName} = shift if @_;
    $self->{tagName};
}

sub appendChild {
    my ($self, $node) = @_;
    $node->parentNode($self);
    $self->childNodes->insertNode($node);
    return $node;
}

sub removeChild {
    my ($self, $node) = @_;
    if ($node->parentNode == $self) {
	undef($node->{parentNode});
	return $self->childNodes->removeNode($node);
    } else {
	die "$node is not a child of $self";
    }
}

sub insertBefore {
    my ($self, $node, $refNode) = @_;
    die "usage error" unless (scalar(@_) == 3);
    my $index = $self->childNodes->nodeIndex($refNode);
    if (defined $index) {
	if ($index <= 0) {
	    $self->childNodes->insertNode($node, 0);
	} else {
	    $self->childNodes->insertNode($node, $index);
	}
    } else {
	die "$refNode is not a child of $self";
    }
    $node->parentNode($self);
}

sub replaceChild {
    my ($self, $node, $refNode) = @_;
    die "usage error" unless (scalar(@_) == 3);
    $self->insertBefore($refNode, $node);
    $self->removeChild($refNode);
}

sub nodeValue {
    my $self = shift; $self->{nodeValue} = shift if @_;
    $self->{nodeValue};
}

sub attributes {
    my $self = shift; $self->{attributes} = shift if @_;
    $self->{attributes};
}

sub getAttribute {
    my ($self, $attname) = @_;
    return $self->{attributes}->{$attname};
}

sub setAttribute {
    my ($self, $attname, $value) = @_;
    $self->{attributes}->{$attname} = $value;
}

sub firstChild {
    my ($self) = @_;
    return $self->childNodes->item(0);
}

sub lastChild {
    my ($self) = @_;
    return $self->childNodes->[$#{$self->childNodes}];
}

sub ownerDocument {
    my $self = shift; $self->{ownerDocument} = shift if @_;
    $self->{ownerDocument};
}

sub getElementsByTagName {
    my ($self, $tag_name) = @_;

    require XML::DOM::Lite::NodeFilter;
    require XML::DOM::Lite::NodeIterator;
    require XML::DOM::Lite::NodeList;

    my $nlist = XML::DOM::Lite::NodeList->new([ ]);

    my $nfilt = XML::DOM::Lite::NodeFilter->new(sub {
        my $n = shift;
	if ($n->tagName eq $tag_name) {
	    return FILTER_ACCEPT;
	} else {
	    return FILTER_REJECT;
	}
    });

    my $niter = XML::DOM::Lite::NodeIterator->new($self, SHOW_ELEMENT, $nfilt);
    while (my $n = $niter->nextNode) {
	$nlist->insertNode($n);
    }
    return $nlist;
}

sub cloneNode {
    my ($self, $deep) = @_;

    my $copy = { };
    @copy{keys %$self}     = values %$self;
    $copy->{childNodes}    = XML::DOM::Lite::NodeList->new([ ]);
    $copy->{attributes}    = \%{$self->attributes};
    $copy->{tagName}       = $self->tagName;
    $copy->{nodeType}      = $self->nodeType;
    $copy->{ownerDocument} = $self->ownerDocument;

    bless $copy, ref($self);

    if ($deep) {
	foreach (@{$self->childNodes}) {
	    $copy->childNodes->insertNode($_->cloneNode($deep));
	}
    }
    return $copy;
}

# breaks cyclic refs from child to parent nodes
sub decycle {
    my ($self, $deep) = @_;
    foreach (@{$self->childNodes}) {
        undef $_->{parentNode};
        undef $_->{ownerDocument};
	if ($deep) {
	    $_->decycle($deep);
	}
    }
}

# rebuilds refs from child to parent nodes
sub recycle {
    my ($self, $deep) = @_;
    foreach (@{$self->childNodes}) {
	$_->parentNode($self);
        if ($self->nodeType & 256) {
            $_->ownerDocument($self);
        } else {
            $_->ownerDocument($self->ownerDocument);
        }
	if ($deep) {
	    $_->recycle($deep);
	}
    }
}

# this is here for curiosity... I was playing with a way
# of creating a unique hash key from a node's type and
# position in the DOM tree to prevent cyclic references
sub hash {
    my $self = shift;
    $hash = 0;
    foreach (split //, shift) {
	$hash = $hash*33 + ord($_);
    }
    return $hash;
}

1;

