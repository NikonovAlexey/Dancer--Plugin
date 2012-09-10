package Dancer::Plugin::uRBAC;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;

use FAW::uRoles;
use Data::Dump qw(dump);

our $VERSION = '0.1';

my $conf = plugin_setting;

=head2 before hook

    Основной механизм установки прав на основе конфигурации и правил. 

    Сначала мы готовим пакет входящих (управляющих) параметров. Затем передаём
их в процедуру проверки роли. 

    Результат проверки мы помещаем в флаг запрещения.

=cut

hook 'before' => sub {
    my $current_role = session->{user}->{roles}  || "guest";
    my $input_method = lc(request->{method})     || "";
    my $input_route  = request->{_route_pattern} || '/';

    $conf->{deny_flag} = $conf->{deny_defaults} || 1;
    my $route_profile = $conf->{roles}->{$input_route} || "";
    
    # разделим роли на блоки (более одной)
    if ($route_profile eq "any") { return $conf->{deny_flag} = 0; };
    
    $conf->{deny_flag} = FAW::uRoles->check_role($current_role, $input_method, $route_profile);
};

=head2 before_template_render hook

    Механизм логирования и управления отрисовкой шаблона.
    
    Процедура выполняет логирование в файл запрошенного действия
и передаёт в шаблон параметры блокировки.

=cut

hook 'before_template_render' => sub {
    my ($values) = @_;
    $values->{deny_flag}        = $conf->{deny_flag};
    $values->{deny_template}    = $conf->{deny_template} || 'blocks/defdeny.tt';
    $values->{rights}           = \&rights;

    #if ($conf->{deny_flag} != 0) {
    #    warning " ::::::::::::: ========== ::::::::::: status: access denied";
    #} else {
    #    warning " ::::::::::::: ========== ::::::::::: status: access granted";
    #};
};

sub rights {
    my $input_method = lc(request->{method})     || "";
    my $current_role = session->{user}->{roles}  || "guest";
    my ( $s ) = @_;
    
    #warning " ========-------------========== $current_role";
    if (FAW::uRoles->check_role($current_role, $input_method, $s) != 0 ) {
        return undef;
    };
    
    return 1; 
};

register 'rights' => \&rights;

=head2 access_status
=head2 access_deny
=head2 access_grant

    Пакет трёх простых процедур, управляющих статусом блокировки: запросить
статус (возвращает текущий статус: 1 = блокируется, 0 = доступно); установить
статус "заблокировано"; установить статус "разрешено"

=cut

register access_status  => sub { return $conf->{deny_flag}; };
register access_deny    => sub { $conf->{deny_flag} = 1; };
register access_grant   => sub { $conf->{deny_flag} = 0; };

register_plugin;

1;
