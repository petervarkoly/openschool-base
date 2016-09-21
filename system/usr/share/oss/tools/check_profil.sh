#!/bin/bash

user=$1
arch=$3
group=$( id -g $user )

. /etc/sysconfig/schoolserver

if [ ! -e $SCHOOL_HOME_BASE/profile/$user/$arch ]; then
	mkdir -m 700 -p $SCHOOL_HOME_BASE/profile/$user/$arch
	chown $user $SCHOOL_HOME_BASE/profile/$user $SCHOOL_HOME_BASE/profile/$user/$arch
fi
USERHOME=$( /usr/sbin/oss_get_home $user )

if [ "${USERHOME/home/}" = "$USERHOME" ]; then
        echo "check_profil.sh error $user does not have homedirectory $USERHOME"
        exit 1
fi

MODE="700"

if [ "$group" = "501" -a "$SCHOOL_TEACHER_OBSERV_HOME" = "yes" -a  "$SCHOOL_MOVE_PROFILE_TO_HOME" = "yes" ]; then
	echo "SCHOOL_TEACHER_OBSERV_HOME and SCHOOL_MOVE_PROFILE_TO_HOME can not be set together to yes"
	exit 1
fi

# Die neuen Ordner werden, falls nicht vorhanden, angelegt
if [ "$SCHOOL_MOVE_PROFILE_TO_HOME" = "yes" ]; then
	for i in Documents  Downloads  Favorites Music Pictures Videos
	do
		if [ ! -d $USERHOME/$i ]; then
			mkdir -m $MODE $USERHOME/$i
			chown $user:$group $USERHOME/$i
		fi
		if [ -d $SCHOOL_HOME_BASE/profile/$user/$arch/$i ]; then
			mv $SCHOOL_HOME_BASE/profile/$user/$arch/$i/* $USERHOME/$i/
			rm -r $SCHOOL_HOME_BASE/profile/$user/$arch/$i/
		fi
	done
	if [ ! -d $USERHOME/WinDesktop ]; then
		mkdir -m $MODE $USERHOME/WinDesktop
		chown $user:$group $USERHOME/WinDesktop
	fi
	if [ -d $SCHOOL_HOME_BASE/profile/$user/$arch/Desktop ]; then
		mv $SCHOOL_HOME_BASE/profile/$user/$arch/Desktop/* $USERHOME/WinDesktop/
		rm -r $SCHOOL_HOME_BASE/profile/$user/$arch/Desktop/
	fi
fi
