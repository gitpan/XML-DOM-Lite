package XML::DOM::Lite::NodeIterator;

use XML::DOM::Lite::NodeList;
use XML::DOM::Lite::NodeFilter;
use XML::DOM::Lite::Constants qw(:all);

=head1 NAME

NodeIterator - DOM style node iterator

=head1 SYNOPSIS

 use XML::DOM::Lite::Node::Constants qw(:all);

 my $nfilt = XML::DOM::Lite::NodeFilter->new(sub {
     my $node = shift;
     if ($node->tagName == 'storage') {
         return FILTER_ACCEPT;
     } else {
         return FILTER_SKIP;
     }
 });

 my $niter = XML::DOM::Lite::NodeIterator->new(
     $template,
     SHOW_ELEMENT, # bitwise combinations supported eg. SHOW_ELEMENT | SHOW_TEXT
     $nfilt,
 );

 my $node = $niter->nextNode();

=cut

sub new {
    my ($class, $root, $whatToShow, $nodeFilter) = @_;

    my $self = bless {
	root       => $root,
	whatToShow => $whatToShow,
    }, $class;

    unless (defined $nodeFilter) {
	$nodeFilter = XML::DOM::Lite::NodeFilter->new(sub { return FILTER_ACCEPT });
    }

    $self->filter($nodeFilter);
    $nodeFilter->set_ShowType($whatToShow);

    return $self;
}

sub getRoot {
    return shift->{root};
}

sub nextNode {
    my $self = shift;

    unless (defined $self->{stack}) {
	if ($self->getRoot->isa('XML::DOM::Lite::NodeList')) {
	    $self->{stack} = XML::DOM::Lite::NodeList->new([@{$self->getRoot}]);
	} else {
	    $self->{stack} = XML::DOM::Lite::NodeList->new([$self->getRoot]);
	}
    }

    my ($node, $found);
    STEP : while (@{$self->{stack}}) {
	$node = shift @{$self->{stack}};
	my $rv = $self->filter->acceptNode($node);

	if ($rv == FILTER_REJECT) {
	    if (@{$node->childNodes}) {
		unshift @{$self->{stack}}, @{$node->childNodes};
	    }
	}
	elsif ($rv == FILTER_ACCEPT) {
	    if (@{$node->childNodes}) {
		unshift @{$self->{stack}}, @{$node->childNodes};
	    }
	    $found = $node;
	    last STEP;
	}
	elsif ($rv == FILTER_SKIP) {
	    next STEP;
	}
	else {
	    die "got garbage from filter '$rv'";
	}
    }

    return $found;
}

sub currentNode {
    my $self = shift; $self->{currentNode} = shift if @_;
    $self->{currentNode};
}

sub previousNode {
    my $self = shift;
    die "Not Yet Implemented!";
    my $node = pop @{$self->{_prev_stack}};
    push @{$self->{_nxt_stack}}, $node;
    do {
	$node = pop @{$self->{_prev_stack}};
	push @{$self->{_nxt_stack}}, $node;
    } until ($self->filter->acceptNode($self));
}

sub filter {
    my $self = shift; $self->{filter} = shift if @_;
    $self->{filter};
}

1;
