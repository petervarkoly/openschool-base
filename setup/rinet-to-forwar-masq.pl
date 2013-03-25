#!/usr/bin/perl
BEGIN
{
        push @INC,"/usr/share/oss/lib/";
}
use strict;
use oss_base;
use oss_utils;

my $oss = oss_base->new();
my $fw     = get_file("/etc/sysconfig/SuSEfirewall2");
$fw =~ /^FW_FORWARD_MASQ="(.*)"$/m;
my $ACCESS = $1;
open RINET, "</etc/rinetd.conf";
while(<RINET>){
        next if /^#/;
        my ( $t, $ep, $ws, $ip ) = split /\s+/;
        next if ( $ws eq $oss->get_school_config("SCHOOL_SERVER") );
        next if ( $ws eq $oss->get_school_config("SCHOOL_MAILSERVER") );
        $ACCESS .= " 0/0,$ws,tcp,$ep,$ip";
}
close RINET;
system("perl -pi -e 's#^FW_FORWARD_MASQ=.*#FW_FORWARD_MASQ=\"$ACCESS\"#' /etc/sysconfig/SuSEfirewall2");

my $ms = $oss->get_school_config("SCHOOL_MONITOR_SERVICES");
$ms ~= s/,rinetd//;
$oss->set_school_config("SCHOOL_MONITOR_SERVICES",$ms);
system("/usr/sbin/oss_ldap_to_sysconfig.pl");

