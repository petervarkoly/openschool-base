#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}
use strict;  
use oss_base;
   
my $uid       = shift;
my $IP        = shift;
my $arch      = shift || '';
   
# Check if the profil exist
system("/usr/sbin/check_profil $uid");

my $oss = oss_base->new();

my $dn = $oss->get_user_dn($uid);
my $mesg = $oss->{LDAP}->search( base => $dn,
                                scope => "base",
                                filter=> "objectClass=SchoolAccount",
                                 attrs=> [ 'configurationValue','homeDirectory','role' ] );
exit if ($mesg->count != 1);
   
my @confs    = $mesg->entry(0)->get_value('configurationValue');
my $home     = $mesg->entry(0)->get_value('homeDirectory');
my $role     = $mesg->entry(0)->get_value('role');
my @newconfs = ();

$oss->{LDAP}->modify( $dn ,  delete => { configurationValue => "LOGGED_ON=$IP" } );

if( $role =~ /students/ && $oss->{SYSCONFIG}->{SCHOOL_ALLOW_STUDENTS_MULTIPLE_LOGIN} ne "yes" )
{
   $oss->{LDAP}->modify( $dn ,  delete => [ 'sambaUserWorkstations' ] );
}
elsif( $role !~ /workstations/ && $oss->{SYSCONFIG}->{SCHOOL_ALLOW_MULTIPLE_LOGIN} ne "yes" )
{
   $oss->{LDAP}->modify( $dn ,  delete => [ 'sambaUserWorkstations' ] );
}

unlink("$home/OSS-Admin.url") if( -e "$home/OSS-Admin.url" );
unlink("$home/Groupware.url") if( -e "$home/Groupware.url" );

$oss->destroy();

