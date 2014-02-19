package Dancer::Plugin::MailMe;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Plugin::Common;
use Dancer::Plugin::DBIC;
use Dancer::Plugin::Email;

use Data::Dump qw(dump);
use FindBin qw($Bin);
use Try::Tiny;
use POSIX 'strftime';

our $VERSION = '0.3';

my $conf = plugin_setting;

=head2 send

Отправляет письмо указанному получателю. На входе указать получателя, тему,
шаблон для обработки и данные для шаблона.

=cut

sub send {
    my ( $recipient, $subject, $template, $template_data ) = @_;
    my $doup = config->{plugins}->{Email}->{techdir};
    my $message = template_process($template, $template_data);
    $recipient = config->{plugins}->{MailMe}->{alias}->{$recipient} ? config->{plugins}->{MailMe}->{alias}->{$recipient} : $recipient;
    
    try {
        my $status = email {
            from    => config->{plugins}->{Email}->{user} || '',
            to      => $recipient,
            cc      => ( $doup eq $recipient ) ? "" : $doup,
            subject => $subject,
            type    => 'html',
            message => $message,
            encoding=> 'base64',
        };
    } catch {
        warning " =========== can't send email";
    }
};

register send   => \&send;

register_plugin;

1;
