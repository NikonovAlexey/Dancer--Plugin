package Dancer::Plugin::Form;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Common;

use Dancer::Engine;

use FAW::uRoles;
use Data::Dump qw(dump);
use FindBin qw($Bin);
use Try::Tiny;
use POSIX 'strftime';

sub foobar {
    my $form = shift;
}

=text

Регистрация процедур плагина

=cut

register foobar => \&foobar;

register_plugin;

1;
