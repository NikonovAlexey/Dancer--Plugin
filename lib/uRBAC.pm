package Dancer::Plugin::uRBAC;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::FlashNote;

use FAW::uRoles;
use Data::Dump qw(dump);

our $VERSION = '0.2';

my $conf = plugin_setting;

=encoding utf-8

=cut

=head1 NAME

Dancer::Plugin::uRBAC - micro Role Based Access Control

=head1 VERSION

0.2

=head1 SYNOPSIS

Опишите конфигурацию доступа к различным точкам.

    config.yml:
        ...
        plugins:
            uRBAC:
            roles:
                /: any
                /page/:url: any
                /page/:url/edit: admin
        ...

Подключите модуль:

    use Dancer::Plugin::uRBAC;

В общем шаблоне выполняйте проверку прав доступа и отрисовку странички запрещения
(для TemplateToolkit):

    [% IF deny_flag != 0; INCLUDE $deny_template; ELSE; content; END %]

В теле основного проекта можно использовать проверку ролей...

    get '/' => sub {
        ...
        if (rights('admin') {
            warning " ::::::::::::::::: your are is admin' rights";
        } else {
            warning " ::::::::::::::::: your are isn't admin";
        }
        ...
    }

... и модификацию прав доступа согласно иной логики:

    get '/page/:url' => sub {
        ...

        if ( foo ) {
            access_deny;
        } else {
            access_grant;
        }

    }

В шаблоне возможно проверять права текущего пользователя следующим образом:

    [% IF rights(admin) %]<a href="modify">изменить содержимое</a>[% END %]

=cut 

=head1 DESCRIPTION

Плагин, добавляющий в Dancer функционал контроля на основе ролей.

При подключении модуля устанавливается два хука: перед вызовом и при отрисовке
шаблона. Кроме того, управлять поведением запрещения можно с помощью
экспортируемых процедур.

При работе модуля используются следующие внешние точки и соглашения:

- session->{user}->{roles} хранит список ролей текущего пользователя;

- если роль не определена, она считается гостевой (guest);

- шаблон запрещения находится в views/components/defdeny.tt;

- шаблон запрещения можно переопределить опцией deny_template в конфиге модуля; 

- проверять права можно прямо в шаблонизаторе, для этого в него передаётся
ссылка на процедуру rights;

=cut

=head2 rights

Сердце модуля - процедура проверки прав доступа. На входе не передаётся
никаких параметров, а на выходе возвращается 1, если доступ запрещается или
undef, если разрешается

=cut

sub rights {
    my $input_method = lc(request->{method})     || "";
    my $current_role = session->{user}->{roles}  || "guest";
    my ( $s ) = @_;
    
    if (FAW::uRoles->check_role($current_role, $input_method, $s) != 0 ) {
        return undef;
    };
    
    return 1; 
}

=head2 say_if_debug

Для удобства отладки зависимый от флага отладки вывод флага отладки

=cut

sub say_if_debug {
    my $debug = config->{plugins}->{uRBAC}->{debug} || 0;
    if ( $debug == 1 ) { warning $_[0]; }
}

=head2 хук before 

Основной механизм установки прав на основе конфигурации и правил. 

Перед вызовом логики работы каждой точки мы инициируем базовые переменные. На
основе внешнего модуля FAW::uRoles и конфигурации config.yaml мы выполняем проверки 
прав доступа текущего пользователя к текущей точке и устанавливаем флаг доступа.
    

=cut

hook 'before' => sub {
    my $current_role = session->{user}->{roles}  || "guest";
    my $input_method = lc(request->{method})     || "";
    my $input_route  = request->{_route_pattern} || '/';
    my $strong_secure= config->{plugins}->{uRBAC}->{strong_secure} || 0;
    my $redirect;
    my $session_lifetime = session->{lifetime}   || time + config->{session_timeout};
    
    $conf->{deny_flag} = $conf->{deny_defaults} || 1;
    my $route_profile = $conf->{roles}->{$input_route} || "";
    
    # Проверим указание "любой" роли для обхода детальной проверки.
    if ($route_profile eq "any") { 
        say_if_debug(sprintf qq( === GRANT access for any user at %s profile),
            $input_route);
        return $conf->{deny_flag} = 0; 
    };
    
    $conf->{deny_flag} = FAW::uRoles->check_role($current_role, $input_method, $route_profile);
    
    say_if_debug(sprintf qq( === try access for '%s' role at %s@%s with status %s),
        $current_role, $input_route, $input_method, 
        ( $conf->{deny_flag} == 1 ) ? "DENIED" : "GRANTED"
    );
    
    # Заблокируем доступ к содержимому и перенаправим к определённому разделу
    if ( ( $strong_secure ) && ( $conf->{deny_flag} == 1 ) ) {
        warning "Try to lock action for user: strong secure is enabled; redirect to $redirect page";
        $redirect     = config->{plugins}->{uRBAC}->{deny_page} || "/deny";
        redirect($redirect);
    };
    
    # Проверим время жизни нашей сессии и выкинем пользователя, если оно было исчерпано
    warning "long session flag is " . session->{longsession};
    if ( $current_role ne "guest" ) {
        if ( session->{longsession} eq "1" ) {
            warning "don't modify session time - long session";
        } elsif ( $session_lifetime > time ) {
            session lifetime => time + config->{session_timeout};
        } else {
            warning "session timeout";
            flash "Вы слишком долго не выполняли никаких действий, поэтому <strong>в целях
            безопасности</strong> система произвела автоматическое завершение сеанса. Но Вы
            можете в любой момент повторно зайти в систему.";
            session user => {
                id  => "",
                fullname => "",
                roles => "guest",
                login => "",
                email => "",
                phone => "",
                status => "",
            };
            redirect("/user/login");
        }
    }
};

=head2 хук before_template_render

Для корректной работы с правами в шаблонизаторе мы должны передать туда
текущее состояние флага запрещения, адрес шаблона с текстом запрещения и ссылку
на процедуру прав доступа.

=cut

hook 'before_template_render' => sub {
    my ($values) = @_;
    $values->{deny_flag}        = $conf->{deny_flag};
    $values->{deny_template}    = $conf->{deny_template} || 'components/defdeny.tt';
    $values->{rights}           = \&rights;
};

=head2 rights

Проверить права доступа текущего пользователя к текущему контенту можно 
и прямо в процедуре контента, для этого регистрируется ключевое слово rights.

На входе следует передать название роли, на которую следует проверить
текущего пользователя.

    my $currights = rights('admin);

Проверка не меняет текущий статус. Для этого следует использовать другие
процедуры.

=cut 

register 'rights' => \&rights;

=head2 access_status

Запросить текущий статус (возвращает текущий статус: 1 = блокируется, 0 =
доступно).

=head2 access_deny

Назначить статус "доступ заблокирован".

=head2 access_grant

Назначить статус "доступ разрешён".

=cut

register access_status  => sub { return $conf->{deny_flag}; };
register access_deny    => sub { $conf->{deny_flag} = 1; };
register access_grant   => sub { $conf->{deny_flag} = 0; };

register_plugin;

1;
