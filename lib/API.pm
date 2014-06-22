package Dancer::Plugin::API;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Common;

use Dancer::Engine;

use Data::Dump qw(dump);
use FindBin qw($Bin);
use Try::Tiny;
use POSIX 'strftime';

=text

Регистрация процедур плагина

Процедура form:
1) указать шаблон формы для вывода;
2) указать таблицу-источник для вывода;

=cut

get '/api/:table' => sub {
    my $condition = params->{'condition'};

    my
};

register_plugin;

1;
