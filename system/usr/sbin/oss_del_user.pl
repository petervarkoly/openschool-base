#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use Net::LDAP::Entry;
use oss_user;
use oss_utils;
binmode STDIN, ':utf8';

my @dns     = ();
my $connect  = { withIMAP => 1 };

while(my $param = shift)
{
    if( $param =~ /text/i ) { $connect->{XML}=0; }
    if( $param =~ /--noplugin/i ) { $connect->{noplugin}=1; }
}

while(<STDIN>){
    # Clean up the line!
    chomp; s/^\s+//; s/\s+$//;

    my ( $key, $value ) = split / /,$_,2;

    next if( getConnect($connect,$key,$value));

    if( $_ ne '' )
    {
      push @dns, $_;
    }
}

# Make OSS Connection
if( defined $ENV{SUDO_USER} )
{
   if( ! defined $connect->{aDN} || ! defined $connect->{aPW} )
   {
       die "Using sudo you have to define the parameters aDN and aPW\n";
   }
}
my $oss = oss_user->new($connect);

foreach my $dn ( @dns )
{
    $oss->delete($dn);
}
