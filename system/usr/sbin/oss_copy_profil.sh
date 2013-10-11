#!/bin/bash
#
# Script to copy a profil for a user
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.#
# Copyright (c) 2009 Peter Varkoly (peter@varkoly.de
#
OPTS=""
. /etc/sysconfig/schoolserver

usage()
{
echo "

Usage: oss_copy_profil.sh uid OS profil ro/rw desktopOnly
	uid		UID of the user
	OS		The target operating system WinNT Win2K WinXP Win3K Linux
	profil  	The name of the profil user to be distributed
	ro/rw		If this parameter is set to rw the profil will be copied read only.
	desktopOnly	If this parameter is set to 1 only the desktop datas will be copyed.

Examples:

	oss_copy_profil.sh bigboss WinXP tteachers rw 1

	oss_copy_profil.sh minibos WinXP Default_User ro 0

"
}
if [ $# -lt 5 ]
then
  usage
  exit 1;
fi

if [ "$1" = "$3" ]
then
  echo "uid and profil must not be identical"
  exit 1;
fi

if [ $2 = 'Linux' ]
then
	IFS=$'\n'
        home=`oss_get_home $1`
	gid=`oss_get_primary_gid $1`
        test -d $home/Desktop && rm -r $home/Desktop
	#these must be deleted
	if [ -e /usr/share/oss/templates/delete-from-linux-profile ]; then
		for i in `cat /usr/share/oss/templates/delete-from-linux-profile`
		do
			if [ -e "$home/$i" ]; then
				rm -rf "$home/$i"
			fi
		done
	fi
	find -P /home/templates/$3/ -type f  -exec touch {} \;
	if [ $5 = 1 ]; then
	        rsync -a --exclude-from=/usr/share/oss/templates/exclude-from-linux-profile /home/templates/$3/Desktop/ /$home/Desktop/
        	chown -R $1:$gid $home/Desktop/
		exit 0
	else
	        rsync -a --exclude-from=/usr/share/oss/templates/exclude-from-linux-profile /home/templates/$3/ /$home/
	fi
        #in this directories we have to sed
        for i in `cat /usr/share/oss/templates/grep-uid-profile`
        do
                if [ -d "$home/$i" ]
                then
			for j in $( find "$home/$i" -P -type f )
                        do
				#First the $HOME
				sed -i s#/home/templates/$3#$home# "$j"
				#Then the $uid
                                sed -i s/$3/$1/g "$j"
                        done
		elif [ -f $home/$i ]
	       	then
			#First the $HOME
			sed -i s#/home/templates/$3#$home# "$home/$i"
			#Then the $uid
			sed -i s/$3/$1/g "$home/$i"
                fi
        done
        chown -R $1:$gid $home
else
	PROFIL="$SCHOOL_HOME_BASE/profile/$1/$2"

	if [ $3 = 'Default_User' ]
	then
	  if [ $2 = 'Vista.V2' ]
	  then
	    TPROFIL='/var/lib/samba/netlogon/Vista/Default User/'
	  else  
	    TPROFIL='/var/lib/samba/netlogon/'$2'/Default User/'
	  fi
	else
	  TPROFIL="/$SCHOOL_HOME_BASE/profile/$3/$2/"
	fi
	if [ ! -e "$TPROFIL" ]
	then
	  echo "Profil path do not exists $TPROFIL"
	  exit
	fi

	if [ $5 = 1 ]; then
		if [ $2 = 'Vista.V2' ]; then
			if [ -e "$TPROFIL/appsFolder.itemdata-ms" ]; then
				cp "$TPROFIL/appsFolder.itemdata-ms" "$PROFIL/"
				chown $1:$gid "$PROFIL/appsFolder.itemdata-ms"
				chmod 700 "$PROFIL/appsFolder.itemdata-ms"
			fi
		fi
		rsync -a      "$TPROFIL/Desktop/"  "$PROFIL/Desktop/"
		chown $1:$gid "$PROFIL/Desktop/"
		chmod -R 700  "$PROFIL/Desktop/"
	fi

	find "$TPROFIL" -iname desktop.ini -exec rm -f {} \;
	test -e $PROFIL && rm -rf $PROFIL

	mkdir   -m 700 -p    $PROFIL
	chown    $1          $PROFIL
	rsync   -a "$TPROFIL/"  "$PROFIL/"
	chown   -R $1        $PROFIL
	chmod   -R 700       $PROFIL
	if [ "$4" = 'ro' ]
	then
	    if [ -e "$PROFIL/ntuser.dat" ]; then
	    	mv "$PROFIL/ntuser.dat" "$PROFIL/ntuser.man"
	    else
	    	mv "$PROFIL/NTUSER.DAT" "$PROFIL/NTUSER.MAN"
	    fi
	fi  
fi
exit 0
