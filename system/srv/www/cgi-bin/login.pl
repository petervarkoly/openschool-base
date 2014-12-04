#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# itool.pl
#

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

$| = 1; # do not buffer stdout

use strict;
use oss_base;
use oss_utils;

use CGI;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use subs qw(exit);
# Select the correct exit function
*exit = $ENV{MOD_PERL} ? \&Apache::exit : sub { CORE::exit };

my $LANG      = uc(substr $ENV{LANG},0,2) || 'DE';
my $TEXT      = { 'EN' => { 'Username' => 'Username',
                                'Password' => 'Password',
                                'Redirect' => 'Redirect',
                                'Login'    => 'Login',
                                'Logout'   => 'Logout',
                                'Language' => 'Language'
                        },
                      'DE' => { 'Username' => 'Benutzername',
                                'Password' => 'Passwort',
                                'Redirect' => 'Weiterleitung',
                                'Login'    => 'Anmelden',
                                'Logout'   => 'Abmelden',
                                'Language' => 'Sprache'
                        }
                    };

my $cgi=new CGI;

my $loginpath = 'https://admin/cgi-bin/login.pl';

my $user    = $cgi->param("uid");
my $pass    = $cgi->param("passwd");
my $logout  = $cgi->param("logout");
my $remote  = $cgi->remote_addr;
my $error   = $cgi->param("ERROR") || '';
my $connect = { aDN => 'anon' };

if( defined $user and defined $pass ){
	my $oss = oss_base->new($connect);
	my $dn  = $oss->get_user_dn("$user");
	if ( $oss->login( $dn, $pass, $remote, 0 ) )
	{
		if( defined $logout )
		{
		        $oss->{LDAP}->modify( $dn, delete => { configurationValue => [ "LOGGED_ON=$remote" ] } );
			login();
		}
		else
		{
			my $cn =  $oss->get_attribute($dn,'cn');
			my $ws = get_name_of_dn($oss->get_workstation($remote));
        		print $cgi->header(-charset=>'utf-8');
      			print "&nbsp;";
			print $cgi->start_form(-action => $loginpath, -target => '_top', -name => 'login_form');
			print $cgi->start_table({-cellspacing => 0, -cellpadding => 0});
			print $cgi->start_Tr();
			print $cgi->start_td({-align => 'right', -valign => 'middle', -class => 'tds'});
			print "&nbsp;";
			print $cgi->end_td();
			print $cgi->start_td({-valign => 'middle', -class => 'tds', -style => 'padding-bottom:10px;'});
			print "Hello $cn! <br>";
			print "Willkommen am $ws!" if( $ws );
			print $cgi->end_td();
			print $cgi->end_Tr();

			print $cgi->start_Tr();
			print $cgi->start_td({-align => 'right', -valign => 'middle', -class => 'tds'});
			print "&nbsp;";
			print $cgi->end_td();
			print $cgi->start_td({-valign => 'middle', -class => 'tds', -style => 'padding-bottom:10px;'});
			print $cgi->submit(-class=> 'button', -name => 'login', -value => $TEXT->{$LANG}->{'Logout'} );
			print $cgi->end_td();
			print $cgi->end_Tr();

			print $cgi->end_table();
			print $cgi->hidden(-name => 'uid',    value => $user);
			print $cgi->hidden(-name => 'passwd', value => $pass);
			print $cgi->hidden(-name => 'logout', value => 1);
			print $cgi->end_form();
			print $cgi->end_html();
		}
	}
	else
	{
	   $error = "Login failed.";
	   login();
	}
}
else
{
        login();
}

sub login
{
        print $cgi->header(-charset=>'utf-8');
	if ($error eq '') {
      		print "&nbsp;";
    	} else {
      		print $cgi->font({-class=>"text", -style=>"color:#ff0000;"}, $error);
    	}
	print "<br>&nbsp;";
	print $cgi->start_form(-action => $loginpath, -target => '_top', -name => 'login_form');
	print $cgi->start_table({-cellspacing => 0, -cellpadding => 0});
	print $cgi->start_Tr();
	print $cgi->start_td({-align => 'right', -valign => 'middle', -class => 'tds'});
	print $cgi->font({-class => 'text'}, $TEXT->{$LANG}->{'Username'});
	print $cgi->end_td();
	print $cgi->start_td({-valign => 'middle', align => 'left', -class => 'tds'});
	print $cgi->textfield(-class => 'input', -style => 'font-weight: normal;', -name => 'uid', -size => 30);
	print "<script>document.login_form.uid.focus();</script>";
	print $cgi->end_td();
	print $cgi->end_Tr();
	
	print $cgi->start_Tr();
	print $cgi->start_td({-align => 'right', -valign => 'middle', -class => 'tds'});
	print $cgi->font({-class => 'text'}, $TEXT->{$LANG}->{'Password'});
	print $cgi->end_td();
	print $cgi->start_td({-valign => 'middle', align => 'left', -class => 'tds'});
	print $cgi->password_field(-class => 'input', -style => 'font-weight: normal;', -name => 'passwd', -size => 30);
	print $cgi->end_td();
	print $cgi->end_Tr();

	print $cgi->start_Tr();
	print $cgi->start_td({-align => 'right', -valign => 'middle', -class => 'tds'});
	print "&nbsp;";
	print $cgi->end_td();
	print $cgi->start_td({-valign => 'middle', -class => 'tds', -style => 'padding-bottom:10px;'});
	print $cgi->submit(-class=> 'button', -name => 'login', -value => $TEXT->{$LANG}->{'Login'} );
	print $cgi->end_td();
	print $cgi->end_Tr();

	print $cgi->end_table();
	print $cgi->end_form();
	print $cgi->end_html();
}
1;
