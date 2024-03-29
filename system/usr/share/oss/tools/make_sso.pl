#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN
{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Time::Local;
use Net::LDAP;
use MIME::Base64;
use oss_base;

my $uid       = shift;
my $IP        = shift;
my $arch      = shift || '';
my $name      = shift || '';
my $timestamp = timelocal(localtime());

# Check if the profil exist
system("/usr/sbin/oss_check_profil $uid");

my $oss = oss_base->new();

my $dn = $oss->get_user_dn($uid);
my $mesg = $oss->{LDAP}->search( base => $dn,
                                scope => "base",
                                filter=> "objectClass=SchoolAccount",
                                 attrs=> [ 'authData','preferredLanguage','homeDirectory','role' ] );
exit if ($mesg->count != 1);

my $authData = $mesg->entry(0)->get_value('authData');
my $LANG     = $mesg->entry(0)->get_value('preferredLanguage');
my $home     = $mesg->entry(0)->get_value('homeDirectory');
my $role     = $mesg->entry(0)->get_value('role');

#First we have to 'log off' other user
my $mesg = $oss->{LDAP}->search( base    => $oss->{SYSCONFIG}->{USER_BASE},
                                          scope   => 'sub',
                                          attrs   => ['uid','cn'],
                                          filter  => "(configurationValue=LOGGED_ON=$IP)"
        );
foreach my $e ( $mesg->entries )
{
	$oss->{LDAP}->modify( $e->dn ,  delete    => { configurationValue => "LOGGED_ON=$IP" } );
}

#Now we ar setting our attributes.
$oss->{LDAP}->modify( $dn ,     add    => { configurationValue => "LOGGED_ON=$IP" } );
if( $role =~ /students/ && $oss->{SYSCONFIG}->{SCHOOL_ALLOW_STUDENTS_MULTIPLE_LOGIN} ne "yes" )
{
   $oss->{LDAP}->modify( $dn ,     add    => { sambaUserWorkstations => $name } );
}
elsif( $role !~ /workstations|sysadmins/ && $oss->{SYSCONFIG}->{SCHOOL_ALLOW_MULTIPLE_LOGIN} ne "yes" )
{
   $oss->{LDAP}->modify( $dn ,     add    => { sambaUserWorkstations => $name } );
}
if(!defined $LANG){
   $LANG=substr($ENV{LANG},3,2);
   if( length($LANG) != 2)
   {
     $LANG = 'EN';
   }
}

if( defined $authData && ( $oss->{SYSCONFIG}->{SCHOOL_ALLOW_SSO} eq "yes" || $oss->{SYSCONFIG}->{SCHOOL_ALLOW_SSO} eq 'yes') )
{
        $authData=decode_base64($authData);
        $authData=encode_base64($authData."\1".$LANG."\1".$IP);
        chomp($authData);

        # For Linux Only
        #system("perl -pi -e s#^URL=.*#URL=https://admin/admin-cgi/login.pl?authData=$authData# $home/Desktop/admin.desktop");
        #system("perl -pi -e s#^URL=.*#URL=https://schoolserver/login.php?authData=$authData# $home/Desktop/groupware.desktop");

        #my $file="/home/profile/$uid/$arch/Desktop/OSS-Admin.url"
        my $file="$home/OSS-Admin.url";
        open(URL,">$file");
        print URL "[InternetShortcut]\r\nURL=https://admin/admin-cgi/login.pl?authData=$authData\r\n";
        close(URL);
        system( "chown $uid.nobody $file; chmod 600 $file");

        $file="$home/Groupware.url";
        open(URL,">$file");
        print URL "[InternetShortcut]\r\nURL=https://schoolserver/cgi-bin/login.pl?authData=$authData\r\n";
        close(URL);
        system( "chown $uid.nobody $file; chmod 600 $file");
}

$oss->destroy();

