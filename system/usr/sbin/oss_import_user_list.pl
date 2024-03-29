#!/usr/bin/perl -w
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
# Copyright (c) 2001 SuSE GmbH Nuernberg, Germany.  All rights reserved.
#
#
# $Id: oss_import_user_list.pl,v 1.12 2007/03/30 12:29:54 pv Exp $
#
BEGIN{
        push @INC,"/usr/share/oss/lib/";
}

use strict;
use Net::LDAP;
use Net::IMAP;
use Data::Dumper;
use Getopt::Long;
use Config::IniFiles;
use CGI;
use ManageSieve;
use oss_group;
use oss_user;
use oss_utils;
use oss_LDAPAttributes;
use Encode qw(encode decode);
use utf8;

# Global variable
my $mailserver   = 'mailserver';
my %options      = ();
my $result       = "";
my $role         = "students";
my $full         = 0;
my $lang         = 'EN';
my $sessionID    = 0;
my $input        = '/tmp/userlist.txt';
my $domain       = `hostname -d`; chomp $domain;
my $LOGDIR       = "/var/log/";
my $PIDFILE      = "/var/run/import_user.pid";
my $DEBUG        = 0;
my $mailenabled  = 0;
my $userpassword = 0;
my $mustchange   = 0;
my $alias        = 0;
my $notest       = 0;
my $resetPW      = 0;
my $message      = {};
my @attr_ext      = ();
my $attr_ext_name = {};
my $cleanClassDirs= 0;
my $allClasses    = 0;
my $identifier    = 'sn-gn-bd';
my $output       = "";
my $admin_user   = `oss_get_uid admin`;
my $admin_group  = `oss_get_gid sysadmins`;
my $admin_home   = `oss_get_home admin`;
my $date         = `date +%Y-%m-%d.%H-%M-%S`; chop $date;

#############################################################################
## Subroutines
#############################################################################

sub usage
{

        print "import_user_list.pl [<options>]\n";
        print "Options:\n";
        print "  --help         Print this help message\n";
        print "  --input        The import file.\n";
        print "                 Default: /tmp/userlist.txt \n";
        print "  --role         Role of the users to import: students|teachers|administration\n";
        print "                 Default: students \n";
        print "  --full         List is a full list. User which are not in the list will be removed.\n";
        print "                 Default: no \n";
        print "                        This parameter has only affect when role=students\n";
        print "  --debug        Run in debug mode, no daemonize\n";
        print "  --admin        The login of the user who makes the import\n";
        print "                 Default: admin \n";
        print "  --domain       The domain of the school\n";
        print "                 Default: the output of `hostname -d` \n";
        print "  --mailenabled  Default value for mailenabled\n";
        print "  --userpassword Default value for userpassword\n";
        print "                 Default: each new user gets its own random password\n";
        print "  --alias        If set, the new users gets the default alias if not already exists\n";
        print "                 Default: no \n";
        print "  --mustchange   If set, the new users must change its password by the first login\n";
        print "                 Default: no \n";
        print "  --lang         The language of the messages\n";
        print "                 Default: EN \n";
        print "  --sessionID    The sessionID of the web session started this script.\n";
        print "  --notest       If this option is not given no changes will be done. The scipt only reports what's to do.\n";
        print "  --resetPW      If this option is set the password of old user will be reseted too.\n";
        print "  --allClasses   The import list contains all classes. Classes which are not in the list will be deleted.\n";
        print "                 This parameter has only affect when role=students\n";
        print "  --cleanClassDirs Remove the content of the directories of the classes.\n";
        print "                 This parameter has only affect when role=students\n";
        print "  --identifier   Which attribute(s) will be used to identify an user.\n";
        print "                 Normaly the sn givenname and birthday combination will be used.\n";
        print "                 Possible values are uid or uniqueidentifier.\n";

}


sub __($)
{
        my $i = shift;
        if( $message->{$i} and ! utf8::is_utf8($message->{$i}) ){
                utf8::decode($message->{$i})
        }
        return $message->{$i} ? $message->{$i} : $i;
}

sub save_file($$){
   my $Lines = shift;
   my $File  = shift;

   open OUTPUT, ">$File";
   foreach(@$Lines){
        print OUTPUT $_."\n";
   }
   close OUTPUT;
   chown($admin_user,$admin_group,$File);
}

sub daemonize
{
  my ($LOGDIR,$PIDFILE,$debug)=@_;
  if ( ! $debug )
  {
    open STDIN,"/dev/null";
    my $logfile = $LOGDIR."/import_user-$date.log";
    system("touch $logfile; chmod 600 $logfile");
    open STDOUT,">>$logfile";
    open STDERR,">>$logfile";
    chdir "/";
    fork && exit 0;
    print "\n\n----------------------------------------\n";
    print `date`;
    print time,": User import successfully forked into background and running on PID ",$$,"\n";
  }
  else
  {
    print time,": User import running in debug-mode on PID ",$$,"\n";
  }
  open  FILE,">$PIDFILE";
  print FILE $$;
  close FILE;
}

sub close_on_error
{
    my $a = shift;
    print STDERR $a."\n";
    system("rm $PIDFILE");

    open( LOGIMPORTLIST,">>$output");
    print LOGIMPORTLIST "---$a";
    close(LOGIMPORTLIST);
    exit 1;
}

#############################################################################
# Parsing the attributes
#############################################################################
$result = GetOptions(\%options,
                        "help",
                        "full",
                        "debug",
                        "alias",
                        "notest",
                        "mustchange",
                        "admin=s",
                        "input=s",
                        "role=s",
                        "domain=s",
                        "lang=s",
                        "mailenabled=s",
                        "userpassword=s",
                        "sessionID=s",
                        "resetPW",
                        "allClasses",
                        "cleanClassDirs",
			"identifier=s"
                        );

if (!$result && ($#ARGV != -1))
{
        usage();
        exit 1;
}
if ( defined($options{'input'}) )
{
        $input = $options{'input'};
}
if ( defined($options{'help'}) )
{
        usage();
        exit 0;
}
if ( defined($options{'role'}) )
{
        $role = $options{'role'};
}
if ( defined($options{'full'}) )
{
        $full = 1;
}
if ( defined($options{'debug'}) )
{
        $DEBUG = 1;
}
if ( defined($options{'notest'}) )
{
        $notest = 1;
}
if ( defined($options{'resetPW'}) )
{
        $resetPW = 1;
}
if ( defined($options{'alias'}) )
{
        $alias = 1;
}
if ( defined($options{'mustchange'}) )
{
        $mustchange = 1;
}
if ( defined($options{'mailenabled'}) )
{
        $mailenabled = $options{'mailenabled'};
}
if ( defined($options{'userpassword'}) )
{
        $userpassword = $options{'userpassword'};
}
if ( defined($options{'domain'}) )
{
        $domain = $options{'domain'};
}
if ( defined($options{'lang'}) )
{
        $lang = $options{'lang'};
}
if ( defined($options{'identifier'}) )
{
       $identifier = $options{'identifier'};
}
if ( defined($options{'sessionID'}) )
{
        $sessionID = $options{'sessionID'};
}
if ( defined($options{'admin'}) )
{
        $admin_user = $options{'admin'};
        $admin_group = `oss_get_primary_gid  $admin_user`;
        $admin_home  = `oss_get_home $admin_user`;
        $admin_user  = `oss_get_uid  $admin_user`;

}
if ( defined($options{'allClasses'}) && $role eq 'students' )
{
        $allClasses = 1;
}
if ( defined($options{'cleanClassDirs'}) && $role eq 'students' )
{
        $cleanClassDirs = 1;
}

daemonize($LOGDIR,$PIDFILE,$DEBUG);
# log the starting options
print "OPTIONS: ".Dumper(\%options);

# make backup from the ldap database id notest!
if( $notest )
{
        print "We created a backup from LDAP into  /home/archiv/befor-import-$role.$date.LDIF\n";
        system("oss_ldapsearch  > /home/archiv/befor-import-$role.$date.LDIF");
}
# Make a new oss connection.
my $oss = oss_user->new({ withIMAP => 1 });

my $SYSADMINSdir = $oss->{SYSCONFIG}->{SCHOOL_HOME_BASE}."/groups/SYSADMINS";
   $output       = $SYSADMINSdir."/import.$date.log";
my $adminDN = 'uid=admin,'.$oss->{SYSCONFIG}->{USER_BASE};

# Set the access rights for the own LDAP attributes
my $teacheraci  = "initials mail title l description street postalcode st c homephone mobile pager facsimiletelephonenumber telephonenumber labeleduri preferredLanguage jpegphoto";
my $childaci    = "preferredLanguage";

if( $role eq 'students' || $role eq 'templates' )
{
  $oss->{LDAP}->modify($adminDN, replace => {"defaultUserAci" => $childaci});
}
else
{
  $oss->{LDAP}->modify($adminDN, replace => {"defaultUserAci" => $teacheraci});
}
if( ! -e '/usr/share/lmd/lang/base_'.$lang.'.ini' )
{
        close_on_error('Transaltaion file does not exists: /usr/share/lmd/lang/base_'.$lang.'.ini');
}
# Setup the messages
my $allmessages = new Config::IniFiles( -file => '/usr/share/lmd/lang/base_'.$lang.'.ini' );
my @parameters = $allmessages->Parameters('IMPORT_USER');
foreach my $attr (@parameters)
{
    my @values = split /;/,$allmessages->val('IMPORT_USER', $attr);
    $message->{lc($attr)} = $values[0];
    foreach my $name (@values)
    {
        $attr_ext_name->{uc($name)} = lc($attr);
    }
}
# Setup the header
open( OUT, ">>$output");
print OUT "role=$role,lang=$lang,test=$notest,full=$full,alias=$alias,mustchange=$mustchange,userpassword=$userpassword,mailenabled=$mailenabled\n";
close( OUT );

#Now let start to do it
my $NEWLIST    = {};
my @CLASSES    = ();
my %ALLCLASSES = ();
my @GROUPS     = ();
my @ALLUID     = ();
my %ALLUSER    = ();
my @AKTUID     = ();
my $DOMAIN     = $domain;
my $PRIMERCLASS= "";
my @lines      = ();
my $ret        = '';

# Variable to handle the file header
my $sep           = "";
my $header        = {};

# Get the list of the classes
foreach my $dn (@{$oss->get_school_groups('class')} )
{
    Encode::_utf8_on($dn);
    push @CLASSES, get_name_of_dn($dn);
}
foreach my $dn (@{$oss->get_school_groups('workgroup')} )
{
    Encode::_utf8_on($dn);
    push @GROUPS, get_name_of_dn($dn);
}
# Get the list of the users
if( $identifier ne 'sn-gn-bd' ){
   $result = $oss->{LDAP}->search (  # perform a search
                       base   => $oss->{SYSCONFIG}->{USER_BASE},
                       scope  => "one",
                       filter => "(&(role=$role*)(uid=*))",
                       attrs  => ['uid','sn', 'givenname', 'birthday',$identifier]
                      );
} else {
    $result = $oss->{LDAP}->search (  # perform a search
                        base   => $oss->{SYSCONFIG}->{USER_BASE},
                        scope  => "one",
                        filter => "(&(role=$role*)(uid=*))",
                        attrs  => ['uid','sn', 'givenname', 'birthday']
                       );
}

foreach my $entry ($result->all_entries)
{
   my $i = $entry->get_value('uid');
   push @ALLUID , $i;
   my $sn = $entry->get_value('sn');
   my $givenname = $entry->get_value('givenname');
   my $birthday = $entry->get_value('birthday');
   Encode::_utf8_on($sn);        #if( ! utf8::is_utf8($sn) );
   Encode::_utf8_on($givenname); #if( ! utf8::is_utf8($givenname) );
   my $key = "$sn-$givenname-$birthday";
   if( $identifier ne 'sn-gn-bd' )
   {
      $key = $entry->get_value($identifier);
   }
   $key =~ s/\s//g;
   $ALLUSER{uc($key)} = $i;
}
print "OLD-USER: ".Dumper(\%ALLUSER);
# -- building file header attributes
foreach my $attr (@userAttributes, @additionalUserAttributes)
{
    push @attr_ext, __($attr);
    $attr = lc($attr);
    $attr_ext_name->{$attr} = uc($attr);
}
my $muster = "";
foreach my $i (@attr_ext)
{
  if( $i ne "")
  {
    $muster.="$i|";
  }
}
chomp $muster;
$muster =~ s/\|$//;

#-- reading the file in a variable
open (INPUT, "<$input")  || close_on_error("<font color='red'>". __LINE__ ." ". __('cant_open_file')."</font>" );
while ( <INPUT> )
{
    Encode::_utf8_on($_);
    print "NOT OK $_\n" if( ! utf8::is_utf8($_) ) ;
    #Clean up some character
    chomp; s/\r$//; s/"//g;
        push @lines, $_;
}
close (INPUT);
#-- empty file
if(scalar(@lines) < 2)
{
    close_on_error( "<font color='red'>".__LINE__ ." ". __('emtpy_file')."</font>" );
}
#-- reading and evaluating the header
my $HEADER = uc(shift @lines);
print "Header".$HEADER."\n";
$HEADER =~ s/^[^A-Z]//;
print "Cleaned Header".$HEADER."\n";
#-- removing white spaces
#$HEADER =~ s/\s+//g;
#-- determine the field separator
#print $HEADER."\n";
print "Muster $muster\n";
$HEADER =~ /($muster)(.+?)($muster)/i;
if( defined $2 )
{
   $sep = $2;
}
else
{
    close_on_error( "<font color='red'>".__LINE__ ." ". __('bad_header')."</font>" );
}
#-- insert for output needed fields
if( $HEADER !~ /$message->{'uid'}/i && $HEADER !~ /uid/i )
{
    $HEADER = $HEADER.$sep.$message->{'uid'};
}
if( $HEADER !~ /$message->{'userpassword'}/i && $HEADER !~ /userpassword/i )
{
    $HEADER = $HEADER.$sep.$message->{'userpassword'};
}
if( $HEADER !~ /$message->{'birthday'}/i && $HEADER !~ /birthday/i )
{
    close_on_error( "<font color='red'>".__LINE__ ." ". __('miss_some_values')." : ".__('birthday')."</font>" );
}
if( $HEADER !~ /$message->{'sn'}/i && $HEADER !~ /sn/i )
{
    close_on_error( "<font color='red'>".__LINE__ ." ". __('miss_some_values')." : ".__('sn')."</font>" );
}
if( $HEADER !~ /$message->{'givenname'}/i && $HEADER !~ /givenname/i )
{
    close_on_error( "<font color='red'>".__LINE__ ." ". __('miss_some_values')." : ".__('givenname')."</font>" );
}
my $counter = 0;
foreach my $i (split /$sep/,$HEADER)
{
    if( is_user_ldap_attribute(lc($attr_ext_name->{uc($i)})) || contains(lc($attr_ext_name->{uc($i)}),\@additionalUserAttributes) || is_user_ldap_attribute(lc($i)) )
    {
            $header->{$counter} = $attr_ext_name->{uc($i)} || lc($i) ;
    }
    else
    {
            print STDERR "Unknown attribute $i on place $counter in the header.\n";
            open( OUT, ">>$output");
            print OUT "---unknown_attr_header<font color='red'>Unknown attribute $i on place $counter in the header</font>\n";
            close( OUT );
    }
    $counter++;
}
print '$header: '.Dumper($header);
print '$attr_ext_name: '.Dumper($attr_ext_name);
foreach my $cl (@CLASSES)
{
   $NEWLIST->{$cl}->{'header'} = $HEADER;
}
# Only studenst will be sorted in class lists.
if( $role ne 'students' )
{
   $NEWLIST->{$role}->{'header'} = $HEADER;
}

# Now we begins du setup the html side
open( OUT, ">>$output");
print OUT "---";
close( OUT );
foreach my $act_line (@lines)
{
    # Logging
    print "------$act_line------\n";
    my %USER = ();
    # Setup some standard values
    $USER{'preferredlanguage'}  = $lang;
    $USER{'role'}               = $role;
    $USER{'class'}              = [];
    $USER{'group'}              = [];
    if( $mailenabled )
    {
      $USER{'mailenabled'} = $mailenabled;
    }
    if( $mustchange )
    {
      $USER{'mustchange'} = 'yes';
    }
    if( $alias )
    {
      $USER{'alias'} = 'yes';
    }
    my $uid     = undef;
    my $ERROR   = 0;
    my $ERRORS = 'user: ';
    my @classes = ();
    my @groups  = ();
    my $MYCLASSES  = "";

    # Pearsing the line
    my @line = split /$sep/, $act_line;
    # Continue if there was an empty line
    next if( scalar (@line) < 3);
    foreach my $h (keys %$header)
    {
      next if( ! defined $header->{$h} );
      if( $header->{$h} eq "class" )
      {  #It may be more then one classes
         foreach my $c (split /\s+/,$line[$h])
         {
	    $c = uc($c);
            $ALLCLASSES{$c} = 1;
            push @classes, $c;
            push @{$USER{'class'}}, $c;
         }
      }
      elsif( $header->{$h} eq "group" )
      {  #It may be more then one groups
         foreach my $c (split /\s+/,$line[$h])
         {
            push @groups, uc($c);
            push @{$USER{'group'}}, uc($c);
         }
      }
      else
      {
         if( ($header->{$h} eq "uid" || $header->{$h} eq "userpassword") && defined($line[$h]) )
         {  #remove white spaces from uid and password
            $line[$h] =~ s/\s//g;
         }
         next if( !$line[$h] );
         $USER{$header->{$h}}  = $line[$h];
         Encode::_utf8_on($USER{$header->{$h}});
      }
        }
    # It is more simplier :-)
    if( scalar(@classes) )
    { # We need this only for reporting
      $MYCLASSES =join(' ',@classes);
      $PRIMERCLASS=$classes[0];
    }

    # If there is no domain defined we use the main mail domain
    if( !defined $USER{'domain'} )
    {
        $USER{'domain'} = $DOMAIN;
    }
    #Check if all classes are present, someone who belongs to all classes
    #can not belong to not existend classes
    if( scalar(@classes) && $classes[0] ne 'ALL' )
    {
        foreach my $c (@classes)
        {
            my $cn = uc($c);
            if( !defined $NEWLIST->{$cn}->{'header'} )
            {
                if( $notest )
                {
                    my $oss_group         = oss_group->new();
                    my $GROUP             = {};
                    $GROUP->{cn}          = $cn;
                    $GROUP->{grouptype}   = 'class';
                    $GROUP->{description} = __('class')." $cn";
                    $GROUP->{bDN}         = $oss->{LDAP_BASE};
                    if( ! $oss_group->add($GROUP) )
                    {
                            print $oss_group->{ERROR}->{code};
                            print $oss_group->{ERROR}->{text};
                            $ERRORS .= "<font color='red'> ERROR by Creating Class $cn</font> <br>\n";
                    }
                    $oss_group->destroy();
                    print "  NEW CLASS $cn:\n";
                    $ERRORS .= "<b>Creating new class: $cn</b><br>\n";
                }
                else
                {
                    print "  NEW CLASS $cn\n";
                    $ERRORS .= "<b>Creating new class: $cn</b><br>\n";
                }
                # Logging
                push @CLASSES, $cn;
                $NEWLIST->{$cn}->{'header'} = $HEADER;
            }
            my $tmp = $oss->get_group_dn($cn);
            push @{$USER{'class'}}, $tmp if ( $tmp );
        }
    }

    #Check if all groups are present
    foreach my $g (@groups)
    {
        my $cn = uc($g);
        next if( $cn =~ /^\-/ );
        if( !contains($cn,\@GROUPS ))
        {
            if( $notest )
            {
                    my $oss_group         = oss_group->new();
                    my $GROUP             = {};
                    $GROUP->{cn}          = $cn;
                    $GROUP->{grouptype}   = 'workgroup';
                    $GROUP->{description} = "$cn";
                    $GROUP->{bDN}         = $oss->{LDAP_BASE};
                    if( ! $oss_group->add($GROUP) )
                    {
                            print $oss_group->{ERROR}->{code};
                            print $oss_group->{ERROR}->{text};
                            $ERRORS .= "<font color='red'> ERROR by Creating Group $cn</font> <br>\n";
                    }
                    $oss_group->destroy();
                    my $command  = "/usr/sbin/oss_add_group.pl text ";
                    my $cmd_args = "cn $cn\n";
                    $cmd_args   .= "grouptype workgroup\n";
                    $cmd_args   .= "description $cn\n";
                    $cmd_args   .= "bDN ".$oss->{LDAP_BASE}."\n";
                    $ret = cmd_pipe($command,$cmd_args);
                    print "  NEW GROUP $cn:\n$cmd_args\n";
                    $ERRORS .= "<b>Creating new group: $cn</b><br>\n";
            }
            else
            {
                    print "  NEW GROUP $cn\n";
                    $ERRORS .= "<b>Creating new group: $cn</b><br>\n";
            }
            # Logging
            push @GROUPS, $cn;
        }
        my $tmp = $oss->get_group_dn($cn);
        push @{$USER{'groups'}}, $tmp if ( $tmp );
    }
    # Analysing the birthday. We accept following forms:
    # DDMMYYYY
    # DD-MM-YYYY DD:MM:YYYY DD MM YYYY
    # YYYY-MM-DD
    $USER{'birthday'} =~ tr/.: /---/;
    if( $USER{'birthday'} =~ /(\d{2})-(\d{2})-(\d{4})/)
    {
      $USER{'birthday'} = "$3-$2-$1";
    }
    elsif ( $USER{'birthday'} =~ /(\d+)-(\d+)-(\d{4})/)
    {
      $USER{'birthday'} = sprintf("$3-%02d-%02d",$2,$1);
    }
    elsif ( $USER{'birthday'} =~ /(\d{4})-(\d{2})-(\d{2})/)
    {
      #Nothing to do it is all right.
    }
    else
    {
       $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}." ".__('birthday_format_false')."</font>\n";
       $ERROR = 1;
    }

    # uid must be lower case
    if( defined  $USER{'uid'} and  $USER{'uid'} ne "" )
    {
               $USER{'uid'} = lc($USER{'uid'});
    }

    # Do this user exist?
    my $key = uc($USER{'sn'}.'-'.$USER{'givenname'}.'-'.$USER{'birthday'});
    if( $identifier ne 'sn-gn-bd' )
    {
       $key = uc($USER{lc($identifier)});
    }
    $key =~ s/\s//g;
    print "  USER-KEY $key\n";
    if( exists($ALLUSER{$key}) )
    {
       $uid=$ALLUSER{$key};
       if( !defined  $USER{'uid'} || $USER{'uid'} eq "" )
       {
               $USER{'uid'} = $uid;
       }
       else
       {
          if( $ALLUSER{$key} ne $USER{'uid'} )
          {
            $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}." ".$USER{'birthday'}.": ".__('same_person')." $uid </font>\n";
          }
       }
    }

    # And now let's do it
    if( defined $uid )
    {
        # Logging
        print "  OLD USER $uid\n";
        #First we make the older user
        my $udn = 'uid='.$uid.','.$oss->{SYSCONFIG}->{USER_BASE};
        my @old_classes    = ();
        my @old_classes_dn = ();
        foreach my $i ( @{$oss->get_classes_of_user($udn)} )
        {
           push @old_classes_dn, $i;
           push @old_classes, get_name_of_dn($i);
        }
        $ERRORS .= "<b>".$USER{'givenname'}." ".$USER{'sn'}."</b>: ".__('old_classes').": ".join(" ",@old_classes)." ".__('new_classes').": ".$MYCLASSES;
        if( $resetPW )
        {
            if( $userpassword )
            {
              $USER{'userpassword'} = $userpassword;
	    }
	    if( defined $USER{'userpassword'} and $USER{'userpassword'} ne "*" and $USER{'userpassword'} ne "" )
	    {
	      my $err = check_pw($USER{'userpassword'});
	      if( $err ne "" )
	      {
	          $ERRORS .= "<font color='red'>".__('incorrect_passwd').$USER{'userpassword'}."</font>";
	          $ERROR = 1;
	      }
	    }
	}
	$ERRORS .= "<br>\n";
        if( $notest )
        {
                if( $resetPW )
                {
                    # If a default password was defined we use it
                    if( $userpassword )
                    {
                      $USER{'userpassword'} = $userpassword;
                    }
                    if( !$USER{'userpassword'} || $USER{'userpassword'} eq "*")
                    {
                       $USER{'userpassword'} = create_secure_pw();
                    }
                    $oss->set_password( $udn, $USER{'userpassword'}, $mustchange, 0,'md5' );
                }
                if( $MYCLASSES ) {
                    $oss->{LDAP}->modify($udn, replace => { 'ou' =>$MYCLASSES });
                }
                else
                {
                    $oss->{LDAP}->modify($udn, delete => { 'ou' =>[] });
                }
                if( $PRIMERCLASS eq 'ALL' )
                {
                    @classes = @CLASSES;
                }
                else
                {
                    @classes = @{$USER{'class'}};
                }
                my ($classes_to_del,$classes_to_add) = group_diff(\@old_classes_dn,\@classes);
                foreach my $g (@$classes_to_del)
                {
                    $oss->delete_user_from_group($udn,$g);
                }
                foreach my $g (@$classes_to_add)
                {
                    $oss->add_user_to_group($udn,$g);
                }
                foreach my $g ( @groups )
                {
                    my $cn = uc($g);
                    if( $cn =~ s/^\-// )
                    {
                        $oss->delete_user_from_group($udn,$oss->get_group_dn($cn));
                    }
                    else
                    {
                        $oss->add_user_to_group($udn,$oss->get_group_dn($cn));
                    }
                }
        }
        push @AKTUID, $uid;
        print Dumper(\%USER);
    }
    else
    {
        # Loging
        print "  NEW USER\n";
        # If a default password was defined we use it
        if( $userpassword )
        {
          $USER{'userpassword'} = $userpassword;
        }

        # It is a new user
        if( !$USER{'userpassword'} || $USER{'userpassword'} eq "*")
        {
           $USER{'userpassword'} = create_secure_pw();
        }
        else
        {
	    my $err = check_pw($USER{'userpassword'});
	    if( $err ne "" )
	    {
                $ERRORS .= "<font color='red'>".__('incorrect_passwd').$USER{'userpassword'}."</font><br>\n";
                $ERROR = 1;
	    }
        }
        if($USER{"sn"} eq "" || $USER{"userpassword"} eq "" )
        {
            $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}.": ".__('miss_some_values')."</font>\n";
            $ERROR = 1;
        }
        else
        {
            if(defined($USER{"uid"}) && $USER{"uid"} ne '' )
            { # there is an uid predefiend let's test it
                if($USER{"uid"} =~ /[^a-zA-Z0-9-_\.]+/)
                {  #   Match a non-word character
                    $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}.": ".__('uid_invalid')."</font>\n";
                    $ERROR = 1;
                }
                elsif( ($USER{"uid"} eq "anyone") || ($USER{"uid"} eq "anybody"))
                { # Don't allow anybody or anyone as uid (these keywords are needed by cyrus for ACLs)
                    $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}.": ".__('value_anyone_not_allowed')."</font>\n";
                    $ERROR = 1;
                }
                else
                {
                    $USER{"uid"} = lc($USER{"uid"});  # uid always lowercase
                    $USER{"mail"} = $USER{"uid"}."@".$USER{"domain"};
                }
            }

            # at time only SMD5 is supported
            #if(length $USER{"userpassword"} < 5 || ( $USER{"pwmech"} eq "SMD5" ? 0 : length($USER{"userpassword"}) > 8 ) ) {
            #    $ERRORS .= "<font color='red'> $USER{'givenname'} $USER{'sn'}: $message->{incorrect_passwd_length}</font>\n";
            #    $ERROR = 1;
            #}
        }
        $USER{"ou"} = $MYCLASSES if( $MYCLASSES );
        print "Befor creating\n".Dumper(\%USER);
        if( !$ERROR )
        { # If no error accours the user will be created
            if( $notest )
            {
                    check_user_ldap_attributes(\%USER,'correct');
                    if( $oss->add(\%USER) )
                    {
                      $USER{userpassword} = $USER{cleartextpassword};
                      $uid         = $USER{'uid'};
                      $ERRORS    .= "<b>".$USER{'givenname'}." ".$USER{'sn'}."</b> ".__('created')." Login: \"$uid\" ".__('class').":".$MYCLASSES." <br>\n";
                      push @AKTUID, $uid;
                    }
                    else
                    {
                      print $oss->{ERROR}->{code}."\n";
                      print $oss->{ERROR}->{text}."\n";
                      $ERROR   = 1;
                      $ERRORS .= "<font color='red'> ".$USER{'givenname'}." ".$USER{'sn'}.": ".__('failed')."<br>".$oss->{ERROR}->{text}.'<br>'.$oss->{ERROR}->{code}."</font>\n";
                    }
            }
            else
            {
                    my $tmp     = check_user_ldap_attributes(\%USER);
                    if( ! defined $USER{uid} || $USER{uid} eq '' )
                    {
                            $oss->create_uid(\%USER);
                    }
                    $uid         = $USER{'uid'} || $USER{'sn'}.'-'.$USER{'givenname'}.'-'.$USER{'birthday'};
                    $ERRORS    .= "<b>".__('new')." ".$USER{'givenname'}." ".$USER{'sn'}.":</b> ".$uid.", ".__('class').":".$MYCLASSES." <br>\n";
                    if( $tmp )
                    {
                            $ERRORS .= "<font color='red'> ".$tmp." </font><br>\n";
                    }
            }
            $ALLUSER{$key}=$uid;
        }
        print "After creating\n".Dumper(\%USER);
    }
    if( $ERROR eq 0 )
    { # Prework for the list:
        my $line = "";
        foreach my $h (sort {$a <=> $b} (keys %$header))
        {
          if( ref $USER{$header->{$h}} eq 'ARRAY' )
          {
             # This is a class or a group
             my @t = ();
             foreach my $g ( @{$USER{$header->{$h}}} )
             {
                    next if ( ! defined $g );
                    next if ( $g =~ /^cn=/ );
                    push @t,$g;
             }
             $line .= join(" ",@t).$sep;
          }
          else
          {
             $line .= $USER{$header->{$h}}.$sep;
          }
        }
        $line =~ s/$sep\$//;
        if( $role eq 'students' )
        {
           $NEWLIST->{$PRIMERCLASS}->{$uid} = $line;
        }
        else
        {
           $NEWLIST->{$role}->{$uid} = $line;
        }
    }

    $ERRORS .= "givenname=".$USER{'givenname'}.";sn=".$USER{'sn'}.";birthday=".$USER{'birthday'}."\n";
    open( OUT, ">>$output");
    print OUT "$ERRORS";
    close( OUT );
}
# Logging
#    print ">>>>>>>>>>>>>>>>DUMP OF THE NEW USER LIST<<<<<<<<<<<<<\n".Dumper($NEWLIST)."\n>>>>>>>>>>>>>>>END DUMP OF THE NEW USER LIST<<<<<<<<<<<<<<<<<<<";
# Save the user list:
system("mkdir -pm 770 $SYSADMINSdir/userimport.$date");
system("cp $input $SYSADMINSdir/userimport.$date/userlist.txt");
system("chown $admin_user:$admin_group $SYSADMINSdir/userimport.$date");
if( $role eq 'students' )
{
    foreach my $cl (@CLASSES)
    {
        my @ClassList = ($HEADER);
        foreach my $h (keys %{$NEWLIST->{$cl}})
        {
            if( $h ne "header" )
            {
                push @ClassList, " ";
                push @ClassList, $NEWLIST->{$cl}->{$h};
            }
        }
        if( scalar @ClassList > 1 )
        {
            save_file( \@ClassList, "$SYSADMINSdir/userimport.$date/userlist.$cl.txt" );
        }
    }
}
else
{
    my @List = ($HEADER);
    foreach my $h (keys %{$NEWLIST->{$role}})
    {
        if( $h ne "header" )
        {
            push @List, " ";
            push @List, $NEWLIST->{$role}->{$h};
        }
    }
    if( scalar @List > 1 )
    {
        save_file( \@List, "$SYSADMINSdir/userimport.$date/userlist.$role.txt" );
    }
}
# Delete old students
if( $role eq 'students' &&  $full )
{
    open( OUT, ">>$output");
    print OUT "---";
    close( OUT );
    my $ind = {};
    $ind->{$_} = 1 foreach(@AKTUID);
    foreach my $uid (@ALLUID )
    {
      if(not exists($ind->{$uid}))
      {
            my $delete_old_student = '';
            if( $notest )
            {
                    $oss->delete($oss->get_user_dn($uid));
                    $delete_old_student .= "uid=$uid#;#message=<b>Login: $uid</b> ".__('deleted')." /home/archiv/$uid.tgz<br>\n";
            }
            else
            {
                    $delete_old_student .= "uid=$uid#;#message=<b>Login: $uid</b> ".__('deleted')."<br>\n";
            }

            open( OUT, ">>$output");
            print OUT "$delete_old_student";
            close( OUT );
      }
    }
}
if( $allClasses )
{   #Remove Classes which are not in the list
    my $MESSAGE = __("<b>Classes to remove:</b>");
    my $oss_group         = oss_group->new();
    foreach my $dn (@{$oss_group->get_school_groups('class')} )
    {
        Encode::_utf8_on($dn);
        my $cn = get_name_of_dn($dn);
	next if( defined $ALLCLASSES{$cn} );
	$MESSAGE .= " $cn";
	$oss_group->delete($dn) if( $notest );
    }
    $oss_group->destroy();
    open( OUT, ">>$output");
    print OUT  "$MESSAGE<br>";
    close( OUT );
}
if( $cleanClassDirs && $notest )
{
    my $MESSAGE = __("<b>Clean up the directories of the classes:</b>");
    foreach my $dn (@{$oss->get_school_groups('class')} )
    {
        Encode::_utf8_on($dn);
        my $cn = get_name_of_dn($dn);
	my $path =  $oss->{SYSCONFIG}->{SCHOOL_HOME_BASE}.'/groups/'.$cn;
	system("rm -rf $path") if( -d $path );
	system("mkdir -m 3771 $path; chgrp $cn $path; setfacl -d -m g::rwx $path;");
	$MESSAGE .= " $path";
    }
    open( OUT, ">>$output");
    print OUT  "$MESSAGE<br>";
    close( OUT );
}
#Some important things to do if it was not a test
if( $notest )
{
    # Syncing mysql settings if necessary
    if( $oss->{SYSCONFIG}->{SCHOOL_USE_EGROUPWARE}  eq 'yes')
    {
        open( OUT, ">>$output");
        print OUT '---syncingdb<b>'.__('syncingdb')."</b>\n";
        close( OUT );
        system("ssh $mailserver /usr/sbin/oss_sync_group_ldap_mysql.pl");
        system("ssh $mailserver /usr/sbin/oss_sync_user_ldap_mysql.pl");
    }
    system("rcnscd  restart");
    system("rcsquid restart");
}
system("rm $PIDFILE");
system("chown root $input");
system("chmod 600  $input");
$oss->destroy();

1;
