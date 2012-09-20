#
#===============================================================================
#
#         FILE: Rbk.pm
#
#  DESCRIPTION: Модуль взаимодействия с финансовой системой РБК
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (NikonovAlexey@inbox.ru), 
#      COMPANY: 
#      VERSION: 1.0
#      CREATED: 18.09.2012 14:52:34
#     REVISION: ---
#===============================================================================

package Dancer::Plugin::Rbk;

use strict;
use warnings;
 
use Dancer ':syntax';
use Dancer::Plugin;

use Data::Dump qw(dump);
use Try::Tiny;
use Carp;

=encoding utf-8

=cut

=head1 NAME

Dancer::Plugin::Rbk - Form Advanced Way

=head1 VERSION

0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

Модуль взаимодействия с платёжной системой РБК Деньги.

Для корректной работы модуля в настройках следует указать Ваши логин и пароль 
в системе РБК.

=cut

=head1 DESCRIPTION

Модуль реализует следующий базовый функционал:

- create_account - выставить счёт на оплату через систему РБК;

- check_account - проверить состояние счёта на оплату в системе РБК;

- visualise_account 

=cut

=head2 create_account

На входе обязательно указываются следующие параметры:

- orderId - номер счёта;

- recipientAmount - сумма операции;

- serviceName - общее описание операции;

Модуль позволяет переопределить следующие дополнительные параметры:

- recipientCurrency - валюта операции (RUB);

- user_email - электронный почтовый ящик пользователя;

- language - язык интерфейса в системе (ru/en);

Следующие параметры берутся из настроек модуля и должны обязательно быть
прописаны в системе:

- eshopId - номер сайта-участника в системе;

- version - версия протокола (1 или 2);

- DueDate - время жизни заказа;

Следующие параметры жёстко прописаны в модуле и не меняются никогда:

- direct = false;

- successUrl = адрес удачной операции вычисляется при успешном завершении платежа;

- failUrl = адрес отменённого платежа;

=cut

sub create_account {

};

=head2 check_account 

=cut

sub check_account {

};

register create_account => \&create_account;
register check_account  => \&check_account;

register_plugin;

1;
