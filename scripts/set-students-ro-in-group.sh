#!/bin/bash
# This script makes the a group directory writable only
# for teachers. Studenst will have ro access.
# Imortant! Using this script all teachers have access to
# all group directories

if [ -z "$1" ]; then
   echo "Usage set-students-ro-in-group.sh Group"
   exit 1
fi

if [ ! -d /home/groups/$1 ]; then
   echo "/home/groups/$1 does not exist or is not a directory"
   exit 1
fi

setfacl -Rb  /home/groups/$1
find /home/groups/$1 -type d -exec chmod 2750 {} \;
find /home/groups/$1 -type f -exec chmod 2640 {} \;
setfacl -Rm  g:students:rx /home/groups/$1
setfacl -Rm  g:teachers:rwx /home/groups/$1
setfacl -Rdm g:teachers:rwx /home/groups/$1
