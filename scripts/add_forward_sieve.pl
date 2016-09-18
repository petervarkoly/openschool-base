#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved
# <peter@varkoly.de>
# Revision: $Rev: 1618 $

BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

$| = 1; # do not buffer stdout

use strict;
use oss_utils;
use oss_base;
use ManageSieve;
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "uid=s"
                        );


my $oss         = oss_base->new({withIMAP=>1});
my $uid         = $options{uid};

my $forw = 'require ["envelope", "fileinto", "reject", "vacation", "regex"] ;

 if header :is "X-Spam-Flag" ["YES"]
 {
    fileinto "Spam";
 }
 else
 {
';


my $udn   = $oss->get_user_dn($uid);
my $forws = $oss->get_attributes($udn,['susemailforwardaddress']);
foreach ( @{$forws->{susemailforwardaddress}} )
{
    $forw .= 'redirect "'.$_.'";'."\n";
}
$forw .= '
    keep; 
 }
';
$oss->connect_sieve($uid);
$oss->{IMAP}->create("user/$uid/forw");
my ($res, $text) = $oss->{SIEVE}->putScript('forw',$forw);
print "$res,$text\n";
$oss->{SIEVE}->setActive('forw');

$oss->destroy();

