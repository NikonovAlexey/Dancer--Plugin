package Dancer::Plugin::FAW;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::uRBAC;

use FAW::Form;
use Validate::Tiny qw(validate);
use Data::Dump qw(dump);

our $VERSION = '0.2';

=encoding utf-8

=cut

=head1 NAME

Dancer::Plugin::FAW - Form Advanced Way

=head1 VERSION

0.2

=head1 SYNOPSIS

После подключения модуля мы можем декларировать формы в описательном виде в
коде программы. Преимущество подхода: возможность быстрого переопределения
полей формы, логики работы с полями, проверок полей и отображения полей в БД
в одном месте.

Задекларируйте описание новой формы

    fawform '/callback' => {
        template    => 'callback-form',
        redirect    => '',
        layout      => '',
        formname    => '',
        fields      => [ 
            { ... },
        ],
        buttons     => [
            { ... },
        ],
        before      => sub {
            ...
        },
        after       => sub {
            ...
        },
    };

Расширьте поля формы в разделе fields и кнопки формы в разделе buttons, как это
описано в FAW::Forms.

Если это необходимо, определите логику работы формы перед её отрисовкой
(before): здесь можно управлять правами, реализовывать подстановку дефолтных значений 
в поля формы.

Определите логику работы формы после отправки данных (after): куда и каким образом
будут помещены данные; куда будет совершён переход (если он отличается от
заданного в поле redirect в зависимости от условий формы); какие дополнительные
действия должна выполнить логика в том или ином случае.

=cut 

=head1 DESCRIPTION

Модуль для продвинутого описания форм. Склеивает FAW::Forms и Dancer с
удобными дополнениями.

=cut

=head2 fawConvertPath 
    
Одна из основных задач - преобразовать точку общего вида к частному, то есть
выполнить замену и подстановку поледержателей на значения поледержателей.

=cut 

sub fawConvertPath {
    my $t = $_[0];
    $t =~ s/:url/$_[1]/;
    return $t;
};

=head2 fawform 

Через описание формы передаётся ряд дополнительных параметров для fawform:
    
- layout = особый макет, который может быть переопределён вместо стандартного
макета вывода. Необязательный параметр, если не указан, то используется
стандартный шаблон;

- template = шаблон, использующийся для вывода формы. Отрисовка формы ведётся
через этот шаблон;

- before = процедура, которая вызывается перед валидацией данных и отрисовкой
шаблона. В аргументах процедуры передаются тип действия (get/post) и текущие
свойства формы (хэш класса FAW::Form).

- after = процедура, которая вызывается после валидации данных и отрисовки
шаблона. В аргументах процедуры передаются тип действия (get/post) и содержимое
отрисованного шаблона.

- redirect = на какую страничку перейти в случае принятия данных формы.

Параметр "action" становится необязательным (задаёт точку сайта, на которую 
будут передаваться данные формы), поскольку он автоматически подставляется
при вызове методов get/post.

Перенаправление можно указать явно в хэше $faw или в хэше config или не
указывать, и перейти к корневой точке (путь "/" = индексная страничка).

=cut

register fawform => sub {
    my ($path, $config) = @_;
    my $url;
    my $z;
    my $results;
    $config->{action} = prefix . $path;
    $config->{layout} ||= config->{layout};

    my $faw = FAW::Form->new($config);
    
    # мы можем определить своё действие для варианта get
    if ($config->{get}) {
        get $path => $config->{get};
    } else {
    # или использовать штатное:
        get $path => sub {
            $faw->map_params(params);
            
            # вызываем предопределённое действие before get
            &{$config->{before}}("get", \$faw) if defined($config->{before});
            
            # формируем шаблон
            $z = template $config->{template}, { form => $faw }, { layout => $config->{layout} };
            
            # вызываем предопределённое действие after get
            &{$config->{after}}("get", \$z) if defined($config->{after});
            return $z;
        };
    };
    
    # мы можем определить своё действие для варианта post
    if ($config->{post}) {
        post $path => $config->{post};
    } else {
        post $path => sub {
            # Сопоставляем переданные параметы с полями формы для
            # того, чтобы пользователь не вводил одно и то же несколько раз
            $faw->map_params(params);
            
            # Выполняем валидацию параметров, если это требуется
            $results = validate(params, $config->{validate}) if defined($config->{validate}) || 0;
            
            # вызываем предопределённое действие before post 
            &{$config->{before}}("post", \$faw) if defined($config->{before});
            
            # или если валидация не определялась, или если валидация прошла
            # успешно...
            if (!defined($config->{validate}) || ($results->{success} == 1)) {
                # вызываем предопределённое действие after post
                &{$config->{after}}("post", \$z) if defined($config->{after});
                redirect $faw->{redirect} || $config->{redirect} || "/";
            } else {
                # Иначе - формируем шаблон и повторяем при необходимости 
                $z = template $config->{template}, { form => $faw }, { layout => $config->{layout} };
                
                # Вызываем предопределённое действие after post
                &{$config->{after}}("post", \$z) if defined($config->{after});
                return $z;
            }
        };
    };
};

register_plugin;

1;
