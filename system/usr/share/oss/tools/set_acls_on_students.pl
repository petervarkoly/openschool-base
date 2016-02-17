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
my $script   = '';

my $oss = oss_base->new();
exit if( lc($oss->get_school_config('SCHOOL_TEACHER_OBSERV_HOME')) ne "yes" );
my $dn = $oss->get_user_dn($UID);
my $mesg = $oss->{LDAP}->search( base => $dn,
                        scope => "base",
                        filter=> "objectClass=SchoolAccount",
                         attrs=> [ 'homeDirectory','role' ] );
$oss->destroy();
exit(1) if( $mesg->count != 1 );

my $role     = $mesg->entry(0)->get_value('role');
exit if( $role !~ /^students/ );
my $home     = $mesg->entry(0)->get_value('homeDirectory');

system("chgrp -R teachers $home; chmod 2770 $home;");
system("find $home ".'-type f -exec setfacl -b {} \\;');
system("find $home ".'-type d -exec setfacl -b {} \\;');
system("find $home ".'-type f -exec chmod g+rw {} \\;');
system("find $home ".'-type d -exec chmod 2770 {} \\;');

