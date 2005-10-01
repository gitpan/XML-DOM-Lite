package XML::DOM::Lite::NodeFilter;
use XML::DOM::Lite::Constants qw(:all);

sub new {
    my ($class, $filterAction) = @_;
    my $self = bless { }, $class;
    $self->set_FilterAction($filterAction);
    return $self;
}

sub getWhatToShow {
    my ($self) = @_;
    return $self->{ShowType} || SHOW_ALL;
}

sub acceptNode {
    my ($self, $node) = @_;
    return (FILTER_REJECT) unless (defined $node->nodeType);
    return (FILTER_REJECT) unless ($self->getWhatToShow & $node->nodeType);
    return $self->{FilterAction}->($node);
}

sub set_ShowType {
    my $self = shift; $self->{ShowType} = shift if @_;
    $self->{ShowType};
}

sub set_FilterAction {
    my $self = shift; $self->{FilterAction} = shift;
}

1;
