#!/usr/bin/perl

use strict;
use Net::LDAP::LDIF;

my $file = shift;
my $base = shift;
my $rm   = shift || undef ;


my $ldif = Net::LDAP::LDIF->new( $file, "r", onerror => 'undef' );
my $ndif = Net::LDAP::LDIF->new( "$file.new", "w", onerror => 'undef' );
while( not $ldif->eof ( ) ) {
  my $entry = $ldif->read_entry ( );
  if ( $ldif->error ( ) ) {
    print "Error msg: ", $ldif->error ( ), "\n";
    print "Error lines:\n", $ldif->error_lines ( ), "\n";
  } else {
    next if( $rm && $entry->dn() =~ /$base$/i );
    next if( !$rm && $entry->dn() !~ /$base$/i );
    $ndif->write_entry($entry); 
  }
}
$ndif->done;
