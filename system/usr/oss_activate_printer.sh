#!/bin/bash 
printer_name=$1
admin_user=$2
password=$r31

/sbin/startproc -l /var/log/activate-printer.log /usr/sbin/cupsaddsmb -H printserver -U ${admin_user}%"${password}" -v $printer_name

