package Dancer::Plugin::Common;

use strict;
use warnings;

use Dancer ':syntax';

use Dancer::Engine;

use Dancer::Plugin;
use Dancer::Plugin::ImageWork;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::FlashNote;
use Dancer::Plugin::uRBAC;

use FAW::uRoles;
use Data::Dump qw(dump);
use FindBin qw($Bin);
use Try::Tiny;
use POSIX 'strftime';

our $VERSION = '0.3';

my $conf = plugin_setting;

=head2 template_process 

Отрисовать в вывод шаблон Template Toolkit с параметрами, указанными на входе.

На входе обязательно указать:
- имя шаблона, который станем отрисовывать;
- набор дополнительных параметров шаблона;

На выходе получить (и встроить) результат отрисовки шаблона;

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

sub template_process {
    my $template    = shift;
    my $params      = shift || { params => "none" };
    my $engine      = engine 'Template';
    my ( $tmpl, $result );
    
    $params->{rights} = \&rights;
    $tmpl = $engine->view($template);
    if ( ! defined($tmpl) ) {
        warning " === can't process $template file: is absend";
        return "can't process $template file: is absend";
    };
    
    try {
        $result = $engine->render($tmpl, $params);
    } catch {
        $result = "can't process $template file: is broken";
        warning " === can't process $template file: is broken";
    };
    
    return $result;
}

=head2 message_process

Служит для отрисовки сообщения по шаблону.
На входе указать message_id и набор параметров. В числе прочих параметров можно
использовать флаг flash, тогда отрисованный шаблон будет автоматически добавлен
к всплывающим сообщениям; и флаг log - ссылка на шаблон будет добавлена в общий
лог.

=cut

sub message_process {
    my $message_id      = shift;
    my $message_params  = shift || { params => "none" };
    my $result      = "";
    my $place_path  = '/../views/messages/';
    my $encode      = config->{engines}->{template_toolkit}->{encoding}
                        || "utf8";
    
    if ( -f "${Bin}${place_path}${message_id}" ) {
        try {
            my $engine = Template->new({
                INCLUDE_PATH    => "${Bin}${place_path}",
                ENCODING        => $encode,
            });
            $engine->process($message_id, $message_params, \$result);
        } catch {
            $result = "message id $message_id is absend";
        };
    } else { $result = "Message file $message_id is absend."; }

    if ( $message_params->{flash} ) { flash $result;  }
    if ( $message_params->{log} ) { warning " === message $message_id"; }
    
    return $result;
}

=head2 asset

Разворачивает имя в полный путь в папке assets/project. Вторым аргументом можно указать тип.

=cut

sub assets {
    return template_process("blocks/assets.tt", { list => \@_ });
}


=head2 transliterate

Транслитерация русской строки в английскую раскладку согласно ГОСТ.

=cut

sub transliterate {
    my $str = shift || "";
    my %hs  = (
        'аА'=>'a',  'бБ'=>'b',  'вВ'=>'v',  'гГ'=>'g',  'дД'=>'d',
        'еЕ'=>'e',  'ёЁ'=>'jo', 'жЖ'=>'zh', 'зЗ'=>'z',  'иИ'=>'i',
        'йЙ'=>'j',  'кК'=>'k',  'лЛ'=>'l',  'мМ'=>'m',  'нН'=>'n',
        'оО'=>'o',  'пП'=>'p',  'рР'=>'r',  'сС'=>'s',  'тТ'=>'t',
        'уУ'=>'u',  'фФ'=>'f',  'хХ'=>'kh', 'цЦ'=>'c',  'чЧ'=>'ch',
        'шШ'=>'sh', 'щЩ'=>'shh','ъЪ'=>'',   'ыЫ'=>'y',  'ьЬ'=>'',
        'эЭ'=>'eh', 'юЮ'=>'ju', 'яЯ'=>'ja', ' '=>'_',
    );
    pop @{([ \map do{$str =~ s|[$_]|$hs{$_}|gi; }, keys %hs ])}, $str;
    
    return $str;
}

=head2 filtrate

Фильтрует ненужные спецсимволы в именах. Дополняет процедуру transliterate для
автоматического преобразования имени статьи.

=cut

sub filtrate {
    my $str = shift;
    
    $str =~ s/  / /g;
    $str =~ s/^ *//;
    $str =~ s/ *$//;
     
    $str =~ s/\W+/_/g;
    $str =~ s/__/_/g;
    $str =~ s/^_*//;
    $str =~ s/_*$//;
    
    return $str;
}


=head1 Parsing pages

Набор процедур парсинга страничек

=cut

sub img_by_num {
    my ( $src, $id ) = @_;
    my ( $image, $suff );
    my $file = "";
    
    try {
        $image = schema->resultset('Image')->find({ id => $id }) || 0;
        $file  = $image->filename || "";
    } catch {
        return "$src$id";
    };
    
    return "$src$id" if $file eq "";
    return "<img internalid='$id' src='" . img_convert_name($file, "small") . "'>";
}

sub img_by_num_lb {
    my ( $src, $id ) = @_;
    my ( $image, $suff );
    my $file = "";
    my ( $name, $ext );

    try {
        $image = schema->resultset('Image')->find({ id => $id }) || 0;
        $file  = $image->filename || "";
        $suff  = $image->alias;
    } catch {
        return "$src$id";
    };
    
    return "$src$id" if $file eq "";
    return "<a href='" . img_convert_name($file, $suff) . "' rel='lightbox'><img internalid='$id' src='" . img_convert_name($file, "small") . "'></a>";
}

sub link_to_text {
    my ( $src, $link ) = @_;
    return "<a href='/page/$link'>$link</a>";
}

sub doc_by_num {
    my ( $src, $id ) = @_;
    my $doc;
    my $file = "";
    my $docname = "";
    
    if ( ! defined($id) ) { return "$src$id" };
    try {
        $doc    = schema->resultset('Document')->find({ id => $id }) || 0;
        $file   = $doc->filename || "";
        $docname= $doc->remark || "";
    } catch {
        return "$src$id";
    };

    $docname ||= $file;
    
    return "$src$id" if $file eq "";
    return "<a href='$file' target='_blank'>$docname</a>";
}

sub parsepage {
    my $text = $_[0];
    
    $text =~ s/(img\s*=\s*)(\d*)/&img_by_num($1,$2)/egm;
    $text =~ s/(imglb\s*=\s*)(\w*)/&img_by_num_lb($1,$2)/egm;
    $text =~ s/(link\s*=\s*)(\w*)/&link_to_text($1,$2)/egm;
    $text =~ s/(doc\s*=\s*)(\d*)/&doc_by_num($1,$2)/egm;
    return $text;
}


hook before_template_render => sub {
    my ($values) = @_;
    $values->{common} = config->{plugins}->{Common} || "";
    $values->{assets} = \&assets;
};

register template_process   => \&template_process;
register message_process    => \&message_process;
register transliterate      => \&transliterate;
register filtrate           => \&filtrate;

register parsepage          => \&parsepage;

register_plugin;

1;
