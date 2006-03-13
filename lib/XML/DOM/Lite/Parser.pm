package XML::DOM::Lite::Parser;

use XML::DOM::Lite::Document;
use XML::DOM::Lite::Node;
use XML::DOM::Lite::Constants qw(:all);

#========================================================================
# These regular expressions have been gratefully borrowed from:
#
# REX/Perl 1.0 
# Robert D. Cameron "REX: XML Shallow Parsing with Regular Expressions",
# Technical Report TR 1998-17, School of Computing Science, Simon Fraser 
# University, November, 1998.
# Copyright (c) 1998, Robert D. Cameron. 
# The following code may be freely used and distributed provided that
# this copyright and citation notice remains intact and that modifications
# or additions are clearly identified.

our $TextSE = "[^<]+";
our $UntilHyphen = "[^-]*-";
our $Until2Hyphens = "$UntilHyphen(?:[^-]$UntilHyphen)*-";
our $CommentCE = "$Until2Hyphens>?";
our $UntilRSBs = "[^\\]]*](?:[^\\]]+])*]+";
our $CDATA_CE = "$UntilRSBs(?:[^\\]>]$UntilRSBs)*>";
our $S = "[ \\n\\t\\r]+";
our $NameStrt = "[A-Za-z_:]|[^\\x00-\\x7F]";
our $NameChar = "[A-Za-z0-9_:.-]|[^\\x00-\\x7F]";
our $Name = "(?:$NameStrt)(?:$NameChar)*";
our $QuoteSE = "\"[^\"]*\"|'[^']*'";
our $DT_IdentSE = "$S$Name(?:$S(?:$Name|$QuoteSE))*";
our $MarkupDeclCE = "(?:[^\\]\"'><]+|$QuoteSE)*>";
our $S1 = "[\\n\\r\\t ]";
our $UntilQMs = "[^?]*\\?+";
our $PI_Tail = "\\?>|$S1$UntilQMs(?:[^>?]$UntilQMs)*>";
our $DT_ItemSE = "<(?:!(?:--$Until2Hyphens>|[^-]$MarkupDeclCE)|\\?$Name(?:$PI_Tail))|%$Name;|$S";
our $DocTypeCE = "$DT_IdentSE(?:$S)?(?:\\[(?:$DT_ItemSE)*](?:$S)?)?>?";
our $DeclCE = "--(?:$CommentCE)?|\\[CDATA\\[(?:$CDATA_CE)?|DOCTYPE(?:$DocTypeCE)?";
our $PI_CE = "$Name(?:$PI_Tail)?";
our $EndTagCE = "$Name(?:$S)?>?";
our $AttValSE = "\"[^<\"]*\"|'[^<']*'";
our $ElemTagCE = "$Name(?:$S$Name(?:$S)?=(?:$S)?(?:$AttValSE))*(?:$S)?/?>?";
our $MarkupSPE = "<(?:!(?:$DeclCE)?|\\?(?:$PI_CE)?|/(?:$EndTagCE)?|(?:$ElemTagCE)?)";
our $XML_SPE = "$TextSE|$MarkupSPE";

#========================================================================

# these have captures for parsing the attributes
our $AttValSE2 = "\"([^<\"]*)\"|'([^<']*)'";
our $ElemTagCE2 = "(?:($Name)(?:$S)?=(?:$S)?$AttValSE2)+(?:$S)?/?>?";

sub new {
    my ($class, %options) = @_;
    my $self = bless {
        stack   => [ ],
        options => \%options,
    }, $class;
    return $self;
}

sub parse {
    my ($self, $XML) = (shift, shift);
    unless (ref($self)) {
        $self = __PACKAGE__->new(@_);
    }
    my @nodes = $self->_shallow_parse($XML);

    $self->{document} = XML::DOM::Lite::Document->new();
    push @{$self->{stack}}, $self->{document};

    STEP : while (my $n = shift @nodes) {
        $n =~ /^$TextSE$/o && do {
            $self->_handle_text_node($n);
            next STEP;
        };
        $n =~ /^$MarkupSPE$/o && do {
            $self->_handle_element_node($n);
            next STEP;
        };
        $n =~ /^<!(?:$DeclCE)?$/ && do {
            $self->_handle_decl_node($n);
            next STEP;
        };
        $n =~ /^<\?(?:$PI_CE)?/ && do {
            $self->_handle_pi_node($n);
            next STEP;
        };
    }
    return $self->{document};
}

sub _shallow_parse { 
    my ($self, $XML) = @_;

    # Check the options.
    my %options = %{$self->{options}};
    if (defined($options{'whitespace'})) {
        my $mode = $options{'whitespace'};
        $XML =~ s/>$S/>/sg,
        $XML =~ s/$S</</sg if (index($mode, 'strip') >= 0);
        $XML =~ s/$S/ /sg  if (index($mode, 'normalize') >= 0);
    }

    return $XML =~ /$XML_SPE/go;
}

sub _handle_decl_node {
    my ($self, $decl) = @_;
}

sub _handle_pi_node {
    my ($self, $pi) = @_;
}

sub _handle_text_node {
    my ($self, $text) = @_;
    $parent = $self->{stack}->[$#{$self->{stack}}];
    $text =~ s/^\n//so; return unless $text;
    return $self->_mk_text_node($text, $parent);
}

sub _handle_element_node {
    my ($self, $elmnt) = @_;
    if ($elmnt =~ /\/($EndTagCE)/o) {
        $self->_handle_element_node_end($1);
    }
    elsif ($elmnt =~ /($ElemTagCE)>$/o) {
        $self->_handle_element_node_start($1);
    }
}

sub _handle_element_node_start {
    my ($self, $elmnt) = @_;
    # this node is a child of the last opened node (top of stack)
    my $parent = $self->{stack}->[$#{$self->{stack}}];
    my $node = $self->_mk_element_node($elmnt, $parent);

    # last opened node to the top of the stack
    push @{$self->{stack}}, $node;

    # deal with XML style empty tags
    if ($elmnt =~ /\/$/) {
	$node = $self->_handle_element_node_end($elmnt);
    }
    if (defined $node->{attributes}->{id}) {
	$self->{document}->setElementById(
            $node->{attributes}->{id}, $node
        );
    }

    return $node;
}

sub _handle_element_node_end {
    my ($self, $elmnt) = @_;

    # node is now closed, pop it off the stack
    pop @{$self->{stack}};

    # parentNode is now at the top of the stack
    return $self->{stack}->[$#{$self->{stack}}];
}

sub _mk_text_node {
    my ($self, $str, $parent) = @_;
    $parent = $self->{stack}->[$#{$self->{stack}}] unless $parent;

    my $node = XML::DOM::Lite::Node->new({
	nodeType      => TEXT_NODE,
	nodeValue     => $str,
    });

    $parent->appendChild($node);
    $node->ownerDocument($self->{document});

    return $node;
}

sub _mk_element_node {
    my ($self, $elmnt, $parent) = @_;

    $elmnt =~ s/^($Name)$S//o;
    my $tagName = $1;

    my $attrs = $self->_parse_attributes($elmnt);
    my $node = XML::DOM::Lite::Node->new({
	nodeType      => ELEMENT_NODE,
	attributes    => $attrs,
	tagName       => $tagName,
    });

    $parent->appendChild($node);
    $node->ownerDocument($self->{document});

    return $node;
}

sub _parse_attributes {
    my ($self, $elmnt) = @_;

    my %attrs;
    while ($elmnt =~ s/$ElemTagCE2//o) {
        $attrs{$1} = $2;
    }

    return \%attrs;
}

1;


__END__


=head1 NAME

Parser - Pure Perl Lite XML Parser

=head1 SYNOPSIS

 use XML::DOM::Lite qw(Parser);
 
 $parser = Parser->new(%options);
 $doc = $parser->parse($xmlstring);
 $doc = $parser->parseFile('/path/to/file.xml');

=head1 DESCRIPTION



=cut
