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

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "debug",
                        "wlan",
                        "addws",
                        "addma",
                );

my $file = shift;

sub debug
{
    print shift."\n" if $DEBUG;
}

sub usage
{
        print   'Usage: add_hosts_to_oss.pl [OPTION]  CSV.file'."\n\n".
                'With this script we can add hosts to the OSS server.'."\n\n".
		'The CSV file must have the following format:'."\n".
		'  Fields must be separated by ";"'."\n".
		'  The Fields can be closed between "-signs'."\n".
		'  The head must contains following fields:'."\n".
		'  * mac	The MAC (hardware addresse) of the WLAN device.'."\n".
		'  Following fields are allowed:'."\n".
		'  * uid 	The uid of the user the WLAN device belongs to. More then one uid must be separated by space.'."\n".
		'  * room       The name of the room the host must be registered. If the room does not exist this will be created'."\n".
		'  * wlan       The host is a WLAN device.'."\n".
		'  * name       The alternate name of the host.'."\n\n".
		'  * hwconf     The hardware configuration of the host.'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                "       No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
                'Optional parameters : '."\n".
                '       -h, --help         Display this help.'."\n".
                '       -d, --debug        Provide debug messages.'."\n";
                '       -w, --wlan         All hosts are WLAN devices. In this case "uid" is a mandatory field.'."\n";
                '           --addws        Crete workstation user account for the host.'."\n";
                '           --addma        Crete windows machine account for the host.'."\n";
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
    my $MAC    = $line[$attrs{'mac'}];
    my $UDN    = defined $attrs{'uid'}    ? $oss->get_user_dn($line[$attrs{'uid'}])    : "" ;
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
	other_name  => $NAME,
	room        => $oss->get_room_by_name($ROOM),
	hwconfig    => $HWCONF,
	wlanaccess  => $WLAN,
	udn         => $UDN
     }
    );
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

        #Check the alternat name.
        if( $HOST->{other_name} ne '' )
        {
                if( $HOST->{other_name} =~ /[^a-zA-Z0-9-]+/ ||
                    $HOST->{other_name} !~ /^[a-zA-Z]/      ||
                    $HOST->{other_name} =~ /-$/             ||
                    length($HOST->{other_name})<2           ||
                    length($HOST->{other_name}) > 15  )
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
        my @dns = $oss->add_host($name.'.'.$domain,$ip,$HOST->{mac},$HOST->{hwconfig},$HOST->{master},$HOST->{wlanaccess});
	
	#Create WLAN access
	if( $HOST->{wlanaccess} )
	{
		debug("Create WLAN access.");
		my $HW = $HOST->{mac};
	        $HW =~ s/:/-/g;
                $result = $oss->{LDAP}->modify($HOST->{udn}, add    => { rasAccess => $HW } );
                if( $result->code )
                {
                        $oss->ldap_error($result);
                        print STDERR "Error by creating rassAccess $name for ".$HOST->{udn}."\n";
                        print STDERR $oss->{ERROR}->{code}."\n";
                        print STDERR $oss->{ERROR}->{text}."\n";
                }
	}

	if( $ADDWS ) {
		if( ! $oss->add( { uid            => $name,
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
