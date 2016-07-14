#!/usr/bin/perl
# Copyright (c) 2016 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
#
# $Id: oss_set_passwd.pl,v 1.6 2007/02/09 17:58:12 pv Exp $
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
my $client   = "";
my $software = "";
#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "description",
                        "client=s",
                        "software=s"
                );
sub usage
{
        print   'Usage: oss_install_software.pl [OPTIONS]'."\n".
                'This script start installation of software on clients.'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                '           --client       Comma separated list of clients. This can be CNs or DNs or "all". '."\n".
                '                          Ex: edv-pc01,edv-pc02'."\n".
                '           --software     Comma separated list of software. This can be CNs or DNs or "all". '."\n".
                '                          Ex: LibreOffice,GrafstatV4.276'."\n".
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
                '       oss_install_software.pl'."\n".
                'DESCRIPTION:'."\n".
                '       This script sets the access for the rooms.'."\n".
                'PARAMETERS:'."\n".
                '       MANDATORY:'."\n".
                '                   --client      : Comma separated list of clients. This can be CNs or DNs or "all". Ex: edv-pc01,edv-pc02'."\n".
                '                   --software    : Comma separated list of software. This can be CNs or DNs or "all". Ex: LibreOffice,GrafstatV4.276'."\n".
                '       OPTIONAL:'."\n".
                '               -h, --help        : Display this help.(type=boolean)'."\n".
                '               -d, --description : Display the descriptiont.(type=boolean)'."\n";
        exit 0;
}

if ( defined($options{'client'}) )
{
        $client=$options{'client'};
}else{
        usage(); exit 0;
}

if ( defined($options{'software'}) )
{
        $software=$options{'software'};
}else{
        usage(); exit 0;
}

my $oss = oss_base->new();
my @clients = split /,/,$client;
my @sw      = split /,/,$software;
my @clientsDN = ();
my @swDN      = ();

if( $client eq "all" )
{
    my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{USER_BASE},
                             filter => "(role=workstations)",
                              scope => 'one',
                             attr   => []
                          );
    foreach my $entry ( $result->entries )
    {
            push @clientsDN, $entry->dn;
    }
}
else
{
    foreach( @clients )
    {
       if( /^uid=/ )
       {
           push @clientsDN, $_;
       }
       else
       {
           push @clientsDN,$oss->get_user_dn($_);
       }
    }
}
foreach( @sw )
{
    if( /^configurationKey=/i )
    {
        push @swDN, $_;
    }
    else
    {
        push @swDN,'configurationKey='.$_.',o=osssoftware,'.$oss->{SYSCONFIG}->{COMPUTERS_BASE};
    }
}

$oss->makeInstallDeinstallCmd('install',\@clientsDN,\@swDN);
