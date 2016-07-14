#!/usr/bin/perl
#Jun 30 06:08:52 schooladmin kernel: [7068589.200657] martian source 192.168.0.2 from 192.168.218.45, on dev eth0
#Jun 30 06:08:52 schooladmin kernel: [7068589.200665] ll header: ff:ff:ff:ff:ff:ff:00:04:00:17:5c:2d:08:06

use strict;
my $messages = "/var/log/messages";

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
                        "help",
                        "description",
                        "messages=s"
                );
sub usage
{
        print   'Usage: /usr/share/oss/tools/find-martian-sources.pl [OPTION]'."\n".
                'This script find the IP and MAC-Adresses of devices which causes martian sources messages'."\n\n".
                'Options :'."\n".
                'Mandatory parameters :'."\n".
                "       No need for mandatory parameters. (There's no need for parameters for running this script.)\n".
                'Optional parameters: '."\n".
                '       -h, --help         Display this help.'."\n".
                '       -d, --description  Display the descriptiont.'."\n";
                '       -m, --messages     Full path to the logfile. Default is /var/log/messages.'."\n";
}
if ( defined($options{'help'}) ){
        usage(); exit 0;
}
if ( defined($options{'messages'}) ){
	$messages = $options{'messages'};
}

my $martians = `grep -P "ll header|martian source" $messages`;
my $found    = {};

foreach( split(/:08:06/,$martians) )
{
   /martian source (.*) from (.*), on dev.*\n.*ff:ff:ff:ff:ff:ff:(.*)/m;
   $found->{$2}->{mac}    = $3;
   $found->{$2}->{serach} = $1;
}

foreach( sort keys( %$found ) )
{
    print "$_,$found->{$_}->{mac},$found->{$_}->{serach}\n";
}

