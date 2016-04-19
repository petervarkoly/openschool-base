#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN
{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use MIME::Base64;
use oss_base;
use oss_utils;

my $UID      = shift;
my $IP       = shift;
my $ARCH     = shift || '';
my $name     = shift || '';
my $script   = '';
my $LANG     = 'DE';
my $home     = '';
my $role     = '';

my $oss = oss_base->new();


my $room     = $oss->get_room_of_ip($IP);
my $wdn      = $oss->get_workstation($IP);
my $cleanup  = $oss->get_school_config("SCHOOL_CLEAN_UP_PRINTERS") || "yes" ;
my $dprint   = $oss->get_vendor_object($wdn,'EXTIS','DEFAULT_PRINTER');
$dprint  = $oss->get_vendor_object($room,'EXTIS','DEFAULT_PRINTER') if( !scalar(@$dprint) );
my $prints   = $oss->get_vendor_object($wdn,'EXTIS','AVAILABLE_PRINTER');
$prints = $oss->get_vendor_object($room,'EXTIS','AVAILABLE_PRINTER') if( !scalar(@$prints));

if( $UID !~ /^root|administrator$/i )
{
	my $dn = $oss->get_user_dn($UID);
	my $mesg = $oss->{LDAP}->search( base => $dn,
                                scope => "base",
                                filter=> "objectClass=SchoolAccount",
                                 attrs=> [ 'preferredLanguage','homeDirectory','role' ] );
	$oss->destroy();
        exit(1) if( $mesg->count != 1 );

	$LANG     = $mesg->entry(0)->get_value('preferredLanguage');
	$home     = $mesg->entry(0)->get_value('homeDirectory');
	$role     = $mesg->entry(0)->get_value('role');

}

print STDERR "netlogon ".xml_time().": $UID $role $IP $ARCH $name\n";
if( $UID =~ /^root|administrator$/i )
{
	$script = `cat /var/lib/samba/netlogon/root.bat`;
}
elsif( $role =~ /^students/ )
{
	$script = `cat /var/lib/samba/netlogon/students.bat`;
}
elsif( $role =~ /^sysadmins/ )
{
	$script = `cat /var/lib/samba/netlogon/sysadmins.bat`;
}
elsif( $role =~ /^teachers/ )
{
	$script = `cat /var/lib/samba/netlogon/teachers.bat`;
}
elsif( $role =~ /^templates/ )
{
	$script = `cat /var/lib/samba/netlogon/templates.bat`;
}
elsif( $role =~ /^workstations/ )
{
	$script = `cat /var/lib/samba/netlogon/workstations.bat`;
}
else
{
	if( -e "/var/lib/samba/netlogon/$role.bat" )
	{
		$script = `cat /var/lib/samba/netlogon/$role.bat`;
	}
	else
	{
		$script = `cat /var/lib/samba/netlogon/students.bat`;
	}
}

#Clean up printers only if is not forbidden.
if( lc($cleanup) ne "no" )
{
	$script .= '(echo strComputer = "."'."\r\n".
	'echo Set objWMIService = GetObject^("winmgmts:\\\" ^& strComputer ^& "\root\cimv2"^)'."\r\n".
	'echo Set colInstalledPrinters =  objWMIService.ExecQuery _'."\r\n".
	'echo ^("Select * from Win32_Printer Where Network = TRUE"^)'."\r\n".
	'echo For Each objPrinter in colInstalledPrinters'."\r\n".
	'echo objPrinter.Delete_'."\r\n".
	'echo Next) > Z:\RemovePrinters.vbs'."\r\n".
	'Z:\RemovePrinters.vbs'."\r\n".
	'del /Q /S Z:\RemovePrinters.vbs'."\r\n";
}

foreach ( @$dprint )
{
        $script .= "rundll32 printui.dll,PrintUIEntry /q /in /n \\\\printserver\\$_ /j\"Default $_\"\r\n"; 
        $script .= "rundll32 printui.dll,PrintUIEntry /y /n \\\\printserver\\$_ /j\"Default $_\"\r\n";   
}

foreach (split /\n/,$prints->[0] )
{
	$script .= "rundll32 printui.dll,PrintUIEntry /q /in /n \\\\printserver\\$_ /j\"$_\"\r\n";
}
system("mkdir -p /var/lib/samba/netlogon/$ARCH/");
open(OUT,">/var/lib/samba/netlogon/$ARCH/$UID.bat");
print OUT $script;
close(OUT);
system("chown $UID /var/lib/samba/netlogon/$ARCH/$UID.bat");
system("chmod 0640 /var/lib/samba/netlogon/$ARCH/$UID.bat");

