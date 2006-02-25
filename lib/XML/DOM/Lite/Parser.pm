package XML::DOM::Lite::Parser;

use XML::DOM::Lite::Document;
use XML::DOM::Lite::Node;
use XML::DOM::Lite::Constants qw(:all);

sub new {
    my ($class) = @_;
    my $self = bless {
	stack => [ ],
    }, $class;
    return $self;
}

sub parse {
    my ($self, $stream, $document) = @_;
    unless (ref $self) {
	$self = __PACKAGE__->new;
    }
    $self->reset;

    $document = XML::DOM::Lite::Document->new()
        unless defined $document;

    $self->document($document);
    $self->_parse(\$stream);
    return $document;
}

sub parseFile {
    my ($self, $filename) = @_;
    unless (ref $self) {
	$self = __PACKAGE__->new;
    }
    my $stream;
    {
        open FH, $filename or
            die "can't open file $filename for reading ".$!;
        local $/ = undef;
        $stream = <FH>;
        close FH;
    }
    return $self->parse($stream);
}

sub reset {
    my $self = shift;
    $self->{stack}   = [ ];
    $self->{_nslist} = [ ];
    undef $self->{document};
}

sub _parse {
    my ($self, $stream) = @_;
    $$stream =~ s/<!DOCTYPE[^<]+//s;
    $$stream =~ s/^<\?[^<]+//s;  # thanks to Robert Frank
    while ($stream && ref $stream && $$stream) {
	$stream = $self->_step($stream);
    }

    # clear the stack
    $self->stack([ ]);

    return $self->document;
}

our @RX = (
    qr/^([^<]*)/so,                       #  0
    qr/^>([^<]*)(<\/?)/so,                #  1
    qr/^<\/([^>]+)>/so,                   #  2
    qr/^<([^>]+)>/so,                     #  3
    qr/^>?(.*)$/so,                       #  4
    qr/\/$/so,                            #  5
    qr/^\s+$/o,                           #  6
    qr/^\n/so,                            #  7
    qr/\n/o,                              #  8
    qr/\r/o,                              #  9
    qr/^(\S+)(\s*(.+))?/so,               # 10
    qr/^\s*$/so,                          # 11
    qr/^\s*([A-Za-z0-9:.]+)\s*=\s*(["'])(.*?)\2/so # 12 - thanks to Robert Frank for this
);

sub _step {
    my ($self, $stream) = @_;

    STEP : {
	unless (+@{$self->stack}) {
	    $$stream =~ s/$RX[0]//s && do {
		$self->_insertTextNode($1, $self->document);
	    };
	    push @{$self->stack}, $self->document;
	    last STEP;
	}

	$$stream =~ s/$RX[1]/$2/ && do {
	    $self->_insertTextNode($1);
	    last STEP;
	};

	$$stream =~ s/$RX[2]/>/ && do {
	    $self->_parseTagClose($1);
	    last STEP;
	};

	$$stream =~ s/$RX[3]/>/ && do {
	    $self->_parseTagOpen($1);
	    last STEP;
	};

	$$stream =~ s/$RX[4]// && do {
	    $self->_insertTextNode($1, $self->document) if ($1);
	    pop @{$self->stack};
	};
    };

    return $stream;
}

sub _parseTagOpen {
    my ($self, $tag, $data) = @_;

    # this node is a child of the last opened node (top of stack)
    my $parentNode = $self->stack->[$#{$self->stack}];
    my $node = $self->_insertElementNode($tag, $parentNode);

    # last opened node to the top of the stack
    push @{$self->stack}, $node;

    # deal with XML style empty tags
    if ($tag =~ s/$RX[5]//) {
	$node = $self->_parseTagClose($tag);
    }

    # insert the text that was captured after the tag
    $self->_insertTextNode($data, $node) if ($data);

    return $node;
}

sub _parseTagClose {
    my ($self, $tag, $data) = @_;

    # node is now closed, pop it off the stack
    pop @{$self->stack};

    # parentNode is now at the top of the stack
    my $parentNode = $self->stack->[$#{$self->stack}];

    $self->_insertTextNode($data, $parentNode) if ($data);

    return $parentNode;
}

sub _insertTextNode {
    my ($self, $str, $parentNode) = @_;
    $parentNode = $self->stack->[$#{$self->stack}] unless $parentNode;

    # normalise white space
    return undef if ($str eq "" or $str =~ $RX[6]);

    $str =~ s/$RX[7]//;

    my $node = XML::DOM::Lite::Node->new({
	nodeType      => TEXT_NODE,
	nodeValue     => $str,
        ownerDocument => $self->document,
    });

    $parentNode->appendChild($node);
    return $node;
}

sub _insertElementNode {
    my ($self, $tag, $parentNode) = @_;

    $tag =~ s/$RX[8]//g;
    $tag =~ s/$RX[9]//g;

    $tag =~ /$RX[10]/;
    my $tagName = $1;
    chomp($tagName);
    my $attrs = $self->_parseAttributes($3, $tagName);

    my $node = XML::DOM::Lite::Node->new({
	nodeType      => ELEMENT_NODE,
	attributes    => $attrs,
	tagName       => $tagName,
        ownerDocument => $self->document,
    });

    if (defined $node->{attributes}->{id}) {
	$self->document->setElementById($node->{attributes}->{id}, $node);
    }

    $parentNode->appendChild($node);
    return $node;
}

sub _parseAttributes {
    my ($self, $attr_str, $tagName) = @_;
    return { } unless $attr_str;

    $attr_str =~ s/$RX[8]/ /g;
    $attr_str =~ s/$RX[5]//;

    my %attrs;
    while ($attr_str) {
	next if ($attr_str =~ s/$RX[11]//);
	if ($attr_str =~ s/$RX[12]//) {
	    $attrs{$1} = $3;
	} else {
	    die "found unparsable garbage hanging around in attribute "
	      ."space for tag [$tagName] '$attr_str'";
	}
    }
    return \%attrs;
}

sub document {
    my $self = shift; $self->{document} = shift if @_;
    $self->{document};
}

sub stack {
    my $self = shift; $self->{stack} = shift if @_;
    $self->{stack};
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

