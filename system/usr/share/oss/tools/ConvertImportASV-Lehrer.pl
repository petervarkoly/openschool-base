#!/usr/bin/perl
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

#Parse parameter
use Getopt::Long;
my %options    = ();
my $result = GetOptions(\%options,
			"help",
			"description",
			"convert_import_file=s",
		);
sub usage
{
	print   'Usage: /usr/share/oss/tools/ConvertImportASV-Lehrer.pl [OPTION]'."\n".
		'With this script we can convert the "ASV-Lehrer" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n\n".
		'Options :'."\n".
		'Mandatory parameters :'."\n".
		'	     --convert_import_file  File path.'."\n".
		'Optional parameters: '."\n".
		'	-h,  --help                 Display this help.'."\n".
		'	-d,  --description          Display the descriptiont.'."\n";
}

if ( defined($options{'help'}) ){
	usage(); exit 0;
}
if( defined($options{'description'}) )
{
	print   'NAME:'."\n".
		'	ConvertImportASV-Lehrer.pl'."\n".
		'DESCRIPTION:'."\n".
		'	With this script we can convert the "ASV-Lehrer" file type into "CSV" file type. (The output results of this script will be in the "/tmp/userlist.txt" file.)'."\n".
		'PARAMETERS:'."\n".
		'	MANDATORY:'."\n".
		'		     --convert_import_file : File path.(type=string)'."\n".
		'	OPTIONAL:'."\n".
		'		-h,  --help                : Display this help.(type=boolean)'."\n".
		'		-d,  --description         : Display the descriptiont.(type=boolean)'."\n";
	exit 0;
}
my $import_file = undef;
if( defined($options{'convert_import_file'}) ){
	$import_file = $options{'convert_import_file'};
}else{
	usage(); exit;
}

open OUT,">/tmp/userlist.txt";
print OUT "NACHNAME;VORNAME;GEBURTSTAG;KLASSE;LOGIN\n";
open(FILE,"< $import_file");
<FILE>;
while(<FILE>) {
	chomp;
	s/"//g;
	print OUT "$_\n";
}
close OUT;
close FILE;
