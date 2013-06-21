#!/bin/bash
. /etc/sysconfig/schoolserver

user=$1
arch=$2
host=$3
if [ ! -e $SCHOOL_HOME_BASE/profile/$user/arch ]; then
	mkdir -m 700 -p $SCHOOL_HOME_BASE/profile/$user/arch
	chown $user $SCHOOL_HOME_BASE/profile/$user $SCHOOL_HOME_BASE/profile/$user/arch
fi
USERHOME=$( /usr/sbin/oss_get_home $user )
MODE="700"
# Die neuen Ordner werden, falls nicht vorhanden, angelegt
if [ ! -d $USERHOME/Documents ]; then
        mkdir -m $MODE $USERHOME/Documents
	chown $user:$group $USERHOME/Documents
fi
if [ ! -d $USERHOME/Downloads ]; then
        mkdir -m $MODE $USERHOME/Downloads
	chown $user:$group $USERHOME/Downloads
fi
if [ ! -d $USERHOME/Favorites ]; then
        mkdir -m $MODE $USERHOME/Favorites
	chown $user:$group $USERHOME/Favorites
fi
if [ ! -d $USERHOME/Music ]; then
        mkdir -m $MODE $USERHOME/Music
	chown $user:$group $USERHOME/Music
fi
if [ ! -d $USERHOME/Pictures ]; then
        mkdir -m $MODE $USERHOME/Pictures
	chown $user:$group $USERHOME/Pictures
fi
if [ ! -d $USERHOME/Videos ]; then
        mkdir -m $MODE $USERHOME/Videos
	chown $user:$group $USERHOME/Videos
fi

