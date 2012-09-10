package Dancer::Plugin::FAW;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use FAW::Form;
use Validate::Tiny qw(validate);
use Data::Dump qw(dump);

our $VERSION = '0.1';

=head2 fawConvertPath 
    
    При вызове функции следует выполнить преобразование общего шаблона пути к
текущему виду. Т.е. заменить аргумент в пути его текущим (актуальным)
значением.

=cut 

sub fawConvertPath {
    my $t = $_[0];
    $t =~ s/:url/$_[1]/;
    return $t;
};

=head2 fawform 

    Мы регистрируем новую процедуру для использования в коде Dancer'а.
Процедура является связующим звеном между модулем FAW::Form (конструктором
формы) и нашей программой.

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
            
            #$config->{action} = fawConvertPath($path, param("url"));
            #$faw->{action} = $config->{action};
            
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
