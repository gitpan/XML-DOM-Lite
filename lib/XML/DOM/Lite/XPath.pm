package XML::DOM::Lite::XPath;

#============================================================================
# This is NOT a full XPath implementation... it should probably be renamed
# to DOM Path

use XML::DOM::Lite::NodeList;
use XML::DOM::Lite::Constants qw(:nodeTypes);

our $DEBUG = 0;

sub new {
    my ($class) = @_;
    return bless { }, $class;
}

sub evaluate {
    my ($self, $path, $context) = @_;
    my @selection;
    while ($path) {
	$self->_parsePath(\$path, $context, \@selection);
    }
    return XML::DOM::Lite::NodeList->new(\@selection);
}

sub node2path {
    my ($self, $node, $context) = @_;
    my $path = "";
    while ($node->parentNode and $node->tagName ne $context->tagName) {
	$path = $path ? $node->tagName."/$path" : $node->tagName;
	$node = $node->parentNode;
    }
    $path = "/$path";
    return $path;
}

sub _parsePath {
    my ($self, $path, $context, $selection) = @_;
    my @stack = ($context);

    while ($$path) {

	my $current = $stack[$#stack];
	last unless defined $current;
	$DEBUG && warn "CURRENT => ".$current->tagName.", PATH => $$path";

	if ($$path =~ s/^\/$//) {
	    # select root
	    SCANUP : while (defined $current->parentNode) {
		last SCANUP if $current->nodeType & DOCUMENT_NODE;
		$current = $current->parentNode;
		$DEBUG && warn "NODETYPE => ".$current->nodeType
		    .", PARENTNODE => ".$current->parentNode;
	    }
	    push @$selection, $current;
	    last;
	}

	if ($$path =~ s/^\/\/(\w+)$//) {
	    @$selection = @{$context->getElementsByTagName($1)};
	    last;
	}

	if ($$path =~ s/^\/?\.\.//) {
	    if ($$path) {
		push @stack, $current->parentNode;
	    } else {
		# just selecting the parent, so short circuit
		push @$selection, $current->parentNode;
		last;
	    }
	    next;
	}

	if ($$path =~ s/^\.//) {
	    if ($$path) {
		push @stack, $current;
	    } else {
		# just selecting current, so short circuit (pointless really
		# because we must already have a ref to the current node)
		push @$selection, $current;
		last;
	    }
	    next;
	}

	if ($$path =~ s/^\/(\w+)(\[([^\]]+)\])?$//) {
	    # at target, so fill selection
	    $DEBUG && warn "AT TARGET, PATH => $1, CURRENT => ".$current->tagName;
	    my @match = grep {
		$_->tagName eq $1;
	    } @{$current->childNodes};
	    if ($2) {
		push @$selection, $self->_parsePredicate($3, @match);
	    } else {
		push @$selection, @match if @match;
	    }
	    next;
	}

	if ($$path =~ s/^\/\*$//) {
	    # wildcard at target, load all childNodes
	    push @$selection, @{$current->childNodes};
	    next;
	}

	if ($$path =~ s/^\/(\w+)(\[([^\]]+)\])?//) {
	    # not at target, so push onto stack if tagName matches
	    my @match = grep {
		$_->tagName eq $1;
	    } @{$current->childNodes};
	    if ($2) {
		my @filtered = $self->_parsePredicate($3, @match);
		if (@filtered > 1) {
		    foreach (@filtered) {
			my $pathcopy = "$$path";
			while ($pathcopy) {
			    $self->_parsePath(\$pathcopy, $_, $selection);
			}
		    }
		} else {
		    push @stack, @filtered;
		}
	    } else {
		push @stack, $match[0] if @match;
	    }
	    next;
	}

	# eat trailing garbage ($DEBUG && warn?)
	$$path =~ s/.*//;
    }
}

sub _parsePredicate {
    my ($self, $pred, @match) = @_;
    my @filtered;
    $DEBUG && warn "parsing predicate $pred";
    if ($pred =~ /^(\d+)$/) {
	push @filtered, $match[$1-1];
    }
    elsif ($pred =~ /^last\(\)(-(\d+))?$/) {
	if (length($1)) {
	    push @filtered, $match[$#match - $2];
	} else {
	    push @filtered, $match[$#match];
	}
    }
    elsif ($pred =~ /^position\(\)([<>=]{1,2})(\d+)$/) {
	# 1 based, not zero based
	foreach (1..@match) {
	    # this eval should be safe as the regex restricts its input
	    # to operators and an integer
	    if (eval "$_ $1 $2") {
		push @filtered, $match[$_-1];
	    }
	}
    }
    elsif ($pred =~ /^@([\w]+)(='([^']*)')?$/) {
	foreach my $node (@match) {
	    $DEBUG && warn "attrName => $1, attrVal => $3";
	    if (defined $node->getAttribute($1)) {
		if ($2) {
		    push @filtered, $node if $node->getAttribute($1) eq $3;
		} else {
		    push @filtered, $node;
		}
	    }
	}
    }

    return @filtered;
}

1;
