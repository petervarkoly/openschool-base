#!/usr/bin/perl

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_group;
use oss_user;
use oss_utils;

my $cn = shift;
$cn = uc($cn);


my $user = oss_user->new( { withIMAP=>1 } );
my $dng = $user->get_group_dn($cn);
my $users =$user->get_users_of_group("$dng");
foreach my $dnu (@$users){
   print "Delete $dnu\n";
   if ( $user->get_primary_group_of_user($dnu)  eq "$dng" ) {
      $user->delete("$dnu");
   }
}

my $group = oss_group->new( { withIMAP=>1 } );

$group->delete("$dng");

system("rm -r /etc/apache2/vhosts.d/oss-ssl/$cn.conf; rmdir /home/$cn");


