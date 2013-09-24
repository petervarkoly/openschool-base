#!/usr/bin/perl

use strict;
use Data::Dumper;
#Parse parameter
use Getopt::Long;

my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "description",
                        "import=s"
                );
my $import = undef;

sub usage
{
        print   'Usage: /usr/share/oss/tools/repair_import_user_list.pl [OPTION]'."\n".
                'This script creates userlist files from the userimport log file.'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                '           --import        The name of the import as written in /var/log/: --import import_user-2013-09-24.12-14-23 '."\n".
                'Optional parameters: '."\n".
                '       -h, --help         Display this help.'."\n".
                '       -d, --description  Display the description.'."\n\n";
}

if (!$result && ($#ARGV != -1)){
        usage(); exit 1;
}
if ( defined($options{'help'}) ){
        usage(); exit 0;
}
if( defined($options{'description'}) ){
        print   'NAME:'."\n".
                '       repair_import_user_list.pl'."\n".
                'DESCRIPTION:'."\n".
                '       This script creates userlist files from the userimport log file.'."\n".
                'PARAMETERS:'."\n".
                '       MANDATORY:'."\n".
                '                   --import      : The name of the import as written in /var/log/: --import import_user-2013-09-24.12-14-23'."\n".
                '       OPTIONAL:'."\n".
                '               -h, --help        : Display this help.(type=boolean)'."\n".
                '               -d, --description : Display the descriptiont.(type=boolean)'."\n";
        exit 0;
}
if ( defined($options{'import'}) )
{
        $import=$options{'import'};
}else{
        usage(); exit 0;
}


my $users={};

my $uid = undef;
my $cla = undef;
my $sn  = undef;
my $gn  = undef;
my $bd  = undef;
my $pw  = undef;

system("mkdir -p -m 770 /home/groups/SYSADMINS/$import" );
system("chgrp SYSADMINS /home/groups/SYSADMINS/$import" );
open INPUT,"</var/log/$import.log";
while(<INPUT>)
{
	#------P1;Delahmet;Aldin;02.02.1999;02021999------
	if( /^\-\-\-\-\-\-(.*);(.*);(.*);(.*);(.*)\-\-\-\-\-\-/ )
	{
		if( defined $uid )
		{
			$users->{$cla}->{$uid}->{sn} = $sn;
			$users->{$cla}->{$uid}->{gn} = $gn;
			$users->{$cla}->{$uid}->{bd} = $bd;
			$users->{$cla}->{$uid}->{pw} = $pw;
			$uid = undef;
		}
		$cla = $1;
		$sn  = $2;
		$gn  = $3;
		$bd  = $4;
		$pw  = $5;
	}
	else
	{
		if( /'uid' => '(.*)'/ )
		{
			$uid = $1;
		}
		if( /'cleartextpassword' => '(.*)'/ )
		{
			$pw = $1;
		}
	}
}
foreach my $cl ( keys %$users )
{
	open OUT,">/home/groups/SYSADMINS/$import/userlist.$cl.txt";
	print OUT "Login;Klasse;Nachname;Vorname;Geburtstag;Passwort\n\n";
	foreach $uid ( keys %{$users->{$cla}} )
	{
		print OUT "$cl;$uid;".$users->{$cla}->{$uid}->{sn}.';'.$users->{$cla}->{$uid}->{gn}.';'.$users->{$cla}->{$uid}->{bd}.';'.$users->{$cla}->{$uid}->{pw}."\n\n";
	}
	close OUT;
}
