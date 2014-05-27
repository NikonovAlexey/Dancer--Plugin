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

hook 'before_template_render' => sub {
    my ($values) = @_;
};

=text

Регистрация процедур плагина

Процедура form:
1) указать шаблон формы для вывода;
2) указать таблицу-источник для вывода;

=cut

register foobar => \&foobar;

register_plugin;

1;
