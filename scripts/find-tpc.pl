#!/usr/bin/perl

BEGIN  { push @INC, "/usr/share/oss/lib/" }

use strict;
use oss_base;
use oss_utils;
use Net::LDAP::LDIF;
my $tpc  = {};
my $f    = shift;

sub get_parent_dn($) {
    my $dn      = shift;

    my ($dummy, $parent) = split /,/,$dn,2;

    return $parent;
}

sub get_name_of_dn($) {
    my $dn      = shift;

    my $first_tag = (split /,/,$dn)[0];
    if( defined $first_tag && $first_tag ne '' ) {
      return (split /=/,$first_tag)[1];
    }
    return undef;
}

#### main ####

my $ldif = Net::LDAP::LDIF->new( $f, "r", onerror => 'undef' );
while( not $ldif->eof ( ) ) {
    my $entry = $ldif->read_entry ( );
    my $cn    = $entry->get_value('cn');
    my $mac   = $entry->get_value('dhcpHWAddress');
    my $CK    = $entry->get_value('configurationKey');
    my $CV    = $entry->get_value('configurationValue');
    if( defined $cn && defined $mac && $cn =~ /(\w+)\-pc00/ )
    {
	$tpc->{$cn}->{mac} = $mac;
    }
    if( defined $CK && $CK eq 'SERIALNUMBER' )
    {
	$cn = get_name_of_dn(get_parent_dn(get_parent_dn($entry->dn)));
	next if ( $cn !~ /(\w+)\-pc00/ );
	$tpc->{$cn}->{SERIALNUMBER} = $CV;
    }
    if( defined $CK && $CK eq 'INVENTARNUMBER' )
    {
	$cn = get_name_of_dn(get_parent_dn(get_parent_dn($entry->dn)));
	next if ( $cn !~ /(\w+)\-pc00/ );
	$tpc->{$cn}->{INVENTARNUMBER} = $CV;
    }
}

my $oss = oss_base->new();
foreach my $k ( keys %$tpc )
{
    print "$k;".$tpc->{$k}->{mac}.";".$tpc->{$k}->{SERIALNUMBER}.";".$tpc->{$k}->{INVENTARNUMBER}."\n";
    my $dn = @{$oss->get_entries_dn("dhcpHWAddress=".$tpc->{$k}->{mac})}[0];
    print $dn."\n";
}
