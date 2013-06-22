#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_set_passwd.pl,v 1.6 2007/02/09 17:58:12 pv Exp $
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"times=s",
			"access=s"
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/set_access_for_rooms.pl [OPTION]'."\n".
		'This script sets the access for the rooms.'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	    --times        Comma separated list of times when the default access have to be set. (Ex: --times=06:00:0111110:1,08:00:0111110:1)'."\n".
		'	    --access	   The access state or command to be set. Please close this between two \' if containing spaces'."\n". 
		'			   Ex: ClientControl:ShutDownCmdSHUTDOWN'."\n".
		'			   Ex: ClientControl:ShutDownCmdREBOOT'."\n".
		'			   Ex: ClientControl:ShutDownCmdLOGOFF'."\n".
		'			   Ex: ClientControl:ScreenCmdLOCK'."\n".
		'			   Ex: ClientControl:ScreenCmdUNLOCK'."\n".
		'			   Ex: ClientControl:WOLCmd'."\n".
		'			   Ex: DEFAULT'."\n".
		'			   Ex: \'all:0 proxy:1 printing:1 mailing:1 samba:1\' '."\n".
		'Optional parameters: '."\n".
		'	-h, --help         Display this help.'."\n".
		'	-d, --description  Display the description.'."\n\n";
}
if (!$result && ($#ARGV != -1)){
	usage(); exit 1;
}
if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) ){
	print   'NAME:'."\n".
		'	set_default_access_for_rooms.pl'."\n".
		'DESCRIPTION:'."\n".
		'	This script sets the default access for the rooms.'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		    --times       : Comma separated list of times when the default access have to be set.(Ex: --times=06:00:0111110:1,08:00:0111110:1) (type=string)'."\n".
		'		    --access	  : The access state or command to be set. Please close this between two \' if containing spaces'."\n". 
		'	OPTIONAL:'."\n".
		'		-h, --help        : Display this help.(type=boolean)'."\n".
		'		-d, --description : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $times  = 0;
my $access = 0;
if ( defined($options{'times'}) )
{
	$times=$options{'times'};
}else{
	usage(); exit 0;
}
if ( defined($options{'access'}) )
{
	$access=$options{'access'};
}else{
	usage(); exit 0;
}

# Make LDAP Connection
my $oss = oss_base->new();

##############################################################################
# now we start to work
my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
                                       scope   => 'sub',
                                       filter  => '(&(Objectclass=SchoolRoom)(description=*)(!(description=ANON_DHCP)))'
                              );
foreach my $room ( $result->all_entries )
{
    foreach ( split /,/,$times )
    {
	$oss->{LDAP}->modify( $room->dn, add => {serviceAccesControl => "$_ $access" } );
    }
}

$oss->destroy();
