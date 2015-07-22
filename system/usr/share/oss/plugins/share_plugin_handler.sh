#!/bin/bash
#
# Handler to execute scripts bey making or closing connection to a share.
# To activate the handler you have to insert following line into the share definition
# root preexec  = /usr/share/oss/plugins/share_plugin_handler.sh open  %S %u %I %a %m 
# root postexec = /usr/share/oss/plugins/share_plugin_handler.sh close %S %u %I %a %m 
# The handler will execute all scripts in the directory
# /usr/share/oss/plugins/shares/%S/[open|close]/ whith the parameter %u %I %a %m
SHARE=$1
TASK=$2
U=$3
IP=$4
ARCH=$5
MACH=$6
. /etc/sysconfig/schoolserver
for i in /usr/share/oss/plugins/shares/$SHARE/$TASK/*
do
   test ! -e $i && continue
   if [ "$SCHOOL_DEBUG" = "yes" ]
   then
      echo "$(date +%Y-%m-%d-%H:%M:%S) $i $U $IP $ARCH $MACH" >> /var/log/oss-share_plugin_handler.log
      $i $U $IP $ARCH $MACH >> /var/log/oss-share_plugin_handler.log  2>&1
   else
      $i $U $IP $ARCH $MACH
   fi
done

