#!/bin/bash 
printer_name=$1
admin_user=$2
password=$3

/sbin/startproc -l /var/log/activate-printer.log /usr/sbin/cupsaddsmb -H printserver -U root%$( oss_get_admin_pw  ) -v $printer_name

