#!/bin/bash
# This is a plugin-scrip for add_group
# This script makes the new group directories writable only
# for teachers. Studenst will have ro access.
# Imortant! Using this script all teachers have access to
# all group directories

while read -r k v
do
    if [ "$k" = "cn" ]; then
        setfacl -b /home/groups/$v
	chmod 2750 /home/groups/$v
	setfacl -Rm  g:students:rx /home/groups/$v
	setfacl -Rm  g:teachers:rwx /home/groups/$v
	setfacl -Rdm g:teachers:rwx /home/groups/$v
    fi
done

