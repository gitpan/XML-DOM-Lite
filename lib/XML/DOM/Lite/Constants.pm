package XML::DOM::Lite::Constants;

require Exporter;
@ISA = qw(Exporter);

our @filterActions = qw(FILTER_ACCEPT FILTER_REJECT FILTER_SKIP);
our @nodeTypes = qw(ELEMENT_NODE ATTRIBUTE_NODE TEXT_NODE DOCUMENT_NODE);
our @showTypes = qw(SHOW_ELEMENT SHOW_ATTRIBUTE SHOW_TEXT SHOW_DOCUMENT SHOW_ALL);

use constant FILTER_ACCEPT  => 1;
use constant FILTER_REJECT  => 2;
use constant FILTER_SKIP    => 3;

use constant SHOW_ELEMENT   => 0x0001;
use constant SHOW_ATTRIBUTE => 0x0002;
use constant SHOW_TEXT      => 0x0004;
use constant SHOW_DOCUMENT  => 0x0100;
use constant SHOW_ALL       => 0xFFFF;

use constant ELEMENT_NODE   => 0x0001;
use constant ATTRIBUTE_NODE => 0x0002;
use constant TEXT_NODE      => 0x0004;
use constant DOCUMENT_NODE  => 0x0100;


@EXPORT_OK = (@nodeTypes, @filterActions, @showTypes);

%EXPORT_TAGS = (
    nodeTypes     => \@nodeTypes,
    filterActions => \@filterActions,
    showTypes     => \@showTypes,
    all           => \@EXPORT_OK,
);

1;
