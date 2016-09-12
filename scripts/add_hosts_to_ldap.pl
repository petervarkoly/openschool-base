#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_utils;
use oss_user;
use Data::Dumper;

my %attrs = ();
my $wlan  = 0;
my $DEBUG = 0;
my $ADDWS = 0;
my $ADDMA = 0;
my $CLEANUP = 0;

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "debug",
                        "wlan",
			"cleanup",
                        "addws",
                        "addma",
                );

my $file = shift;

sub debug
{
    my $out = shift;
    print $out."\n" if $DEBUG;
}

sub usage
{
        print   'Usage: add_hosts_to_oss.pl [OPTION]  CSV.file'."\n\n".
                'With this script we can add hosts to the OSS server.'."\n\n".
		'The CSV file must have the following format:'."\n".
		'  Fields must be separated by ";"'."\n".
		'  The Fields can be closed between "-signs'."\n".
		'  The head must contains following fields:'."\n".
		'  * mac	The MAC (hardware addresse) of the device.'."\n".
		'		When the device has ETH and WLAN card this must be the MAC of the ETH device.'."\n".
		'  Following fields are allowed:'."\n".
		'  * wmac	The MAC (hardware addresse) of the WLAN device.'."\n".
		'  * uid 	The uid of the user the WLAN device belongs to. More then one uid must be separated by space.'."\n".
		'  * room       The name of the room the host must be registered. If the room does not exist this will be created'."\n".
		'  * wlan       The host is a WLAN device.'."\n".
		'  * name       The alternate name of the host.'."\n".
		'  * hwconf     The hardware configuration of the host.'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                "       No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
                'Optional parameters : '."\n".
                '       -h, --help         Display this help.'."\n".
                '       -d, --debug        Provide debug messages.'."\n".
                '       -w, --wlan         All hosts are WLAN devices. In this case "uid" is a mandatory field.'."\n".
                '           --addws        Crete workstation user account for the host.'."\n".
                '           --addma        Crete windows machine account for the host.'."\n\n";
}
if ( defined($options{'help'}) ){
        usage(); exit 0;
}
if ( defined($options{'wlan'}) ){
	$wlan = 1;
}
if ( defined($options{'debug'}) ){
	$DEBUG = 1;
}


open IN,"<$file" or die("Can not open file '$file'");
my $head = <IN>;
chomp $head;
my $i = 0;
foreach(split(/;/,$head))
{
   $attrs{lc($_)} = $i;
   $i++; 
}
debug(Dumper(\%attrs));

defined $attrs{'mac'} or die("The mac address is a mandatory field.");

if( $wlan )
{
	defined $attrs{'uid'} or die("The owner uid is a mandatory field if the hosts are wlan devices.");
}

my $oss    = oss_user->new();
my $domain = $oss->{SYSCONFIG}->{SCHOOL_DOMAIN};

while(<IN>)
{
    chomp;
    s/"//g;
    my @line   = split(/;/,$_);
    my $MAC    = uc($line[$attrs{'mac'}]);
    my $UDN    = defined $attrs{'uid'}    ? $oss->get_user_dn($line[$attrs{'uid'}])    : "" ;
    my $WMAC   = defined $attrs{'wmac'}   ? $line[$attrs{'wmac'}]   : undef ;
    my $WLAN   = defined $attrs{'wlan'}   ? $line[$attrs{'wlan'}]   : $wlan ;
    my $HWCONF = defined $attrs{'hwconf'} ? $line[$attrs{'hwconf'}] : undef ;
    my $NAME   = defined $attrs{'name'}   ? $line[$attrs{'name'}]   : '' ;

    #Determine first the room
    my $ROOM = "";
    if( defined $attrs{'room'} ) 
    {
        $ROOM = $line[$attrs{'room'}];
    }
    else
    {
        if( $oss->is_teacher($UDN))
	{
		$ROOM = "Lehrer";
	}
	else
	{
		my $classes = $oss->get_classes_of_user($UDN);
		$ROOM = get_name_of_dn($classes->[0]);
	}
    }

    #Now let's do the job:
    #1. Le's see if the room does exists:
    if( $oss->is_unique($ROOM,'room') )
    {
        my $free  = (keys(%{$oss->get_free_rooms()}))[0];
        $oss->add_room($free,$ROOM,$HWCONF);
	print "Create new room $ROOM, $free\n";
    }
    my $result= addHost( {
    	mac         => $MAC,
	wmac        => $WMAC,
	other_name  => $NAME,
	room        => $oss->get_room_by_name($ROOM),
	hwconfig    => $HWCONF,
	wlanaccess  => $WLAN,
	udn         => $UDN
     }
    );
    $oss->make_delete_user_webdavshare($UDN,1);
    print Dumper($result);
}

sub host_exists
{
        my $host = shift;
        my $res = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "relativeDomainName=$host",
                                         attrs  => [] );
        return $res->count if( !$res->code );
        return 0;

}

sub ip_exists
{
        my $ip   = shift;
        return 1 if($oss->get_workstation($ip));
        my $res = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "ARecord=$ip",
                                         attrs  => [] );
        return $res->count if( !$res->code );
        return 0;

}

sub get_next_free_pc 
{
        my $room = shift;
        my @hosts= ();
        my $roomnet    = $oss->get_attribute($room,'dhcpRange').'/'.$oss->get_attribute($room,'dhcpNetMask');
        if( $roomnet !~ /\d+\.\d+\.\d+\.\d+\/\d+/ ) {
                return @hosts;
        }
        my $roompref   = $oss->get_attribute($room,'description');
        my $block      = new Net::Netmask($roomnet);
        my %lhosts     = ();
        my $schoolnet  = $oss->get_school_config('SCHOOL_NETWORK').'/'.$oss->get_school_config('SCHOOL_NETMASK');
        my $sblock     = new Net::Netmask($schoolnet);
        my $base       = $sblock->base();
        my $broadcast  = $sblock->broadcast();
        my $counter    = -1;
        foreach my $i ( $block->enumerate() )
        {
                if(  $i ne $base && $i ne $broadcast )
                {
                        $counter ++;
                        next if ( ip_exists($i) );
                        next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
                        my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
                        $hostname =~ s/_/-/;
                        next if ( host_exists($hostname) );
                        return ( $hostname, $i );
                }
        }
        return ();
}

sub addHost($)
{
	my $HOST  = shift;
	debug("addHost started:");
	debug(Dumper($HOST));

	my ($name,$ip) = get_next_free_pc($HOST->{room});
	debug("Next free PC: $name,$ip");


	#Check the mac address:
        if( !check_mac($HOST->{mac}) )
        {
            return { TYPE => 'ERROR' ,
                     CODE => 'HW_ADDRESS_INVALID',
                     MESSAGE => "The hardware address is invalid",
                     MESSAGE1 => $HOST->{mac},
                   };
        }
        my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
                           filter => "(dhcpHWAddress=ethernet ".$HOST->{mac}.")",
                           attrs  => ['cn']
                         );
        if($result->count() > 0)
        {
            my $cn = $result->entry(0)->get_value('cn');
            return { TYPE => 'ERROR' ,
                     CODE => 'HW_ALREADY_EXISTS',
                     MESSAGE  => "The hardware address already exists.",
                     NOTRANSLATE_MESSAGE1 => "$cn => ".$HOST->{mac}
                   };
        }

	if( defined $HOST->{wmac} )
	{
		#Check the wmac address:
		if( !check_mac($HOST->{wmac}) )
		{
		    return { TYPE => 'ERROR' ,
		             CODE => 'HW_ADDRESS_INVALID',
		             MESSAGE => "The wmac hardware address is invalid",
		             MESSAGE1 => $HOST->{wmac},
		           };
		}
		my $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DHCP_BASE},
		                   filter => "(dhcpHWAddress=ethernet ".$HOST->{wmac}.")",
		                   attrs  => ['cn']
		                 );
		if($result->count() > 0)
		{
		    my $cn = $result->entry(0)->get_value('cn');
		    return { TYPE => 'ERROR' ,
		             CODE => 'HW_ALREADY_EXISTS',
		             MESSAGE  => "The wmac hardware address already exists.",
		             NOTRANSLATE_MESSAGE1 => "$cn => ".$HOST->{wmac}
		           };
		}
	}

        #Check the alternat name.
        if( $HOST->{other_name} ne '' )
        {
                if( $HOST->{other_name} =~ /[^a-zA-Z0-9-]+/ ||
                    $HOST->{other_name} !~ /^[a-zA-Z]/      ||
                    $HOST->{other_name} =~ /-$/             ||
                    length($HOST->{other_name})<2 
	        )
                {
                    return { TYPE    => 'ERROR' ,
                             CODE    => 'INVALID_HOST_NAME',
                             MESSAGE => "The alternate host name is invalid."
                           };
                }
                $result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{DNS_BASE},
                                   filter => 'relativeDomainName='.$HOST->{other_name},
                                   attrs  => ['aRecord']
                                 );
                if($result->count() > 0)
                {
                    return { TYPE => 'ERROR' ,
                             CODE => 'HOST_ALREADY_EXISTS',
                             MESSAGE => "The alternate host name already exists.",
                             NOTRANSLATEMESSAGE1 => "IP: ".$result->entry(0)->get_value('aRecord')
                           };
                }
                if(!$oss->is_unique($HOST->{other_name},'uid'))
                {
                    return { TYPE => 'ERROR' ,
                             CODE => 'NAME_ALREADY_EXISTS',
                             MESSAGE => "The alternate host name will be used allready as userid."
                           };
                }
		$name = $HOST->{other_name};
        }
	#Add host realy
        my @dns = $oss->add_host($name.'.'.$domain,$ip,$HOST->{mac},$HOST->{hwconfig},$HOST->{master},$HOST->{wlanaccess});

	#This host has 2 network cards
	if( defined $HOST->{wmac} )
	{
	      my ($tmp,$ip) = get_next_free_pc($HOST->{room});
              $oss->add_host($name.'-wlan.'.$domain,$ip,$HOST->{wmac},'wlanclone',0,1);
	}

	#Create WLAN access
	if( $HOST->{wlanaccess} )
	{
		debug("Create WLAN access.");
		my $HW = $HOST->{mac};
	        $HW =~ s/:/-/g;
		#First we have to delete all old entries
		$result = $oss->{LDAP}->search( base   => $oss->{SYSCONFIG}->{USER_BASE},
                                                filter => "(rasAccess=$HW)",
                                                 scope => 'one',
                                                attr   => []
                                      );
		foreach my $entry ( $result->entries )
		{
			$oss->{LDAP}->modify( $entry->dn, delete => { rasAccess => $HW } );	
		}
                $result = $oss->{LDAP}->modify($HOST->{udn}, add    => { rasAccess => $HW } );
                if( $result->code )
                {
                        $oss->ldap_error($result);
                        print STDERR "Error by creating rassAccess $name for ".$HOST->{udn}."\n";
                        print STDERR $oss->{ERROR}->{code}."\n";
                        print STDERR $oss->{ERROR}->{text}."\n";
                }
		#if user $HOST->{udn} has rasAccess=no then delete it
		$result = $oss->{LDAP}->search( base   => $HOST->{udn},
                                          filter => "(rasAccess=no)",
                                           scope => 'base',
                                          attr   => ['rasAccess']
                                  );
                if($result->count() > 0)
                {
			$oss->{LDAP}->modify( $HOST->{udn}, delete => { rasAccess => "no" } );
                }
	}

	if( $ADDWS ) {
		if( ! $oss->add( { uid             => $name,
			     sn                    => $name.' Workstation-User',
			     role                  => 'workstations',
			     userpassword          => $name,
			     sambauserworkstations => $name
			   } ))
		{
			print STDERR $oss->{ERROR}->{text}."\n";
		}
	}
	if( $ADDMA ) {
		if( ! $oss->add( { uid            => $name.'$',
			     sn                    => 'Machine account '.$name ,
			     description           => 'Machine account '.$name ,
			     role                  => 'machine',
			     userpassword          => '{crypt}*'
			   } ) )
		{
			print STDERR $oss->{ERROR}->{text}."\n";
		}
	}
	return { 
		TYPE => 'SUCCESS' ,
                CODE => 'HOST_CREATED_SUCCESSFULLY',
                MESSAGE => "The host $name was created succesfully."
       };
}
