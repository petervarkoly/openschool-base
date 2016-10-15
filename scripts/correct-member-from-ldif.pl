#!/usr/bin/perl
BEGIN{
    push @INC,"/usr/share/oss/lib/";
}

use strict;
use oss_base;
use oss_utils;
use Net::LDAP::LDIF;

my $file = shift;
my $oss  = oss_base->new();

my $ldif = Net::LDAP::LDIF->new( $file, "r", onerror => 'undef' );
while( not $ldif->eof() ) {
  my $entry = $ldif->read_entry();
  if( $entry->exists('groupType') and $entry->get_value('groupType') ne 'primary' )
  {
      print $entry->dn()."\n";

      foreach my $member( $entry->get_value('member') )
      {
           $oss->{LDAP}->modify( dn => $entry->dn(), add => { member => $member } );
      }
      foreach my $memberof( $entry->get_value('memberof') )
      {
           $oss->{LDAP}->modify( dn => $entry->dn(), add => { memberof => $memberof } );
      }
  }
}
$ldif->done ( );


