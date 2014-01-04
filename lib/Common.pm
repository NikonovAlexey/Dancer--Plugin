package Dancer::Plugin::Common;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::ImageWork;
use Dancer::Plugin::DBIC;

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

sub template_process {
    my $engine_name = shift;
    my $params      = shift || { params => "none" };
    my $result      = "";
    my $place_path  = config->{engines}->{template_toolkit}->{path}
                        || '/../views/components/';
    my $encode      = config->{engines}->{template_toolkit}->{encoding}
                        || "utf8";

    try {
        my $engine = Template->new({
            INCLUDE_PATH    => "${Bin}${place_path}",
            ENCODING        => $encode,
        });
        $engine->process($engine_name, $params, \$result);
    } catch {
        $result = " $place_path template is wrong ";
    };
    
    return $result;
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

=head1 Parsing pages

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
    return "<a href='" . img_convert_name($file, "orig") . "' rel='lightbox'><img internalid='$id' src='" . img_convert_name($file, $suff) . "'></a>";
}

sub link_to_text {
    my ( $src, $link ) = @_;
    return "<a href='/page/$link'>$link</a>";
}

sub parsepage {
    my $text = $_[0];
    
    $text =~ s/(img\s*=\s*)(\d*)/&img_by_num($1,$2)/egm;
    $text =~ s/(imglb\s*=\s*)(\w*)/&img_by_num_lb($1,$2)/egm;
    $text =~ s/(link\s*=\s*)(\w*)/&link_to_text($1,$2)/egm;
    return $text;
}

hook before_template_render => sub {
    my ($values) = @_;
    $values->{common}             = config->{plugins}->{Common} || "";
};

register template_process   => \&template_process;
register transliterate      => \&transliterate;

register parsepage          => \&parsepage;

register_plugin;

1;
