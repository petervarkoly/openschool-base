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
my $hwconf   = "";
my $promptly = 0;
#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "description",
                        "promptly",
                        "client=s",
                        "hwconf=s",
                        "software=s"
                );
sub usage
{
        print   'Usage: oss_install_software.pl [OPTIONS]'."\n".
                'This script start installation of software on clients.'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                '           --client       Semicolon separated list of clients. This can be CNs or DNs or "all". '."\n".
                '                          Ex: edv-pc01;edv-pc02'."\n".
                '           --software     Semicolon separated list of software. This can be CNs or DNs. '."\n".
                '                          Ex: LibreOffice;GrafstatV4.276'."\n".
                'Optional parameters: '."\n".
                '           --hwconf       Semicolon separated list of software. This can be CNs or DNs or "all".'."\n".
                '       -p, --promptly     Start intstallation promptly.'."\n\n";
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
                '                   --client      : Semicolon separated list of clients. This can be CNs or DNs or "all". Ex: edv-pc01;edv-pc02'."\n".
                '                   --software    : Semicolon separated list of software. This can be CNs or DNs. Ex: LibreOffice;GrafstatV4.276'."\n".
                '       OPTIONAL:'."\n".
                '                   --hwconf      : Semicolon separated list of software. This can be CNs or DNs or "all". Ex: hwconf0,hwconf13'."\n".
                '               -p, --promptly    : Start intstallation promptly.'."\n";
                '               -h, --help        : Display this help.(type=boolean)'."\n".
                '               -d, --description : Display the descriptiont.(type=boolean)'."\n";
        exit 0;
}

if ( defined($options{'promptly'}) )
{
	$promptly = 1;
}
if ( defined($options{'hwconf'}) )
{
        $hwconf=$options{'hwconf'};
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
my @clients = split /;/,$client;
my @sw      = split /;/,$software;
my @hw      = split /;/,$hwconf;
my @hwConf  = ();
my @clientsDN = ();
my @clientsCN = ();
my @swDN      = ();


#Find HWConfigs
if( $hwconf eq 'all' )
{
    foreach my $HW ( @{$oss->get_HW_configurations(0)}  )
    {
        push @hwConf,'configurationKey='.$HW->[0].','.$oss->{SYSCONFIG}->{COMPUTERS_BASE};
    }
}
else
{
    foreach( @hw )
    {
        if( /^configurationKey=/ )
        {
	    push @hwConf, $_;
	}
        else
        {
            push @hwConf,'configurationKey='.$_.','.$oss->{SYSCONFIG}->{COMPUTERS_BASE};
        }
    }

}
#Find Clients
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
            push @clientsCN, get_name_of_dn($entry->dn);
    }
}
else
{
    foreach( @clients )
    {
       if( /^uid=/ )
       {
           push @clientsDN, $_;
           push @clientsCN, get_name_of_dn($_);
       }
       else
       {
           push @clientsCN, $_;
           push @clientsDN,$oss->get_user_dn($_);
       }
    }
}

#Find software
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

foreach my $hwDn ( @hwConf )
{
    foreach my $pkgDn ( @swDN )
    {
	$oss->add_config_value( $hwDn, 'SWPackage', $pkgDn);
    }
}

if( $promptly )
{
	makeInstallationNow(\@clientsCN);
}

