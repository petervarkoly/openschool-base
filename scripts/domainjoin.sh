#!/bin/bash

. /etc/sysconfig/schoolserver

net dom join -S $1 -U $1\\administrator%$2  domain=$SCHOOL_WORKGROUP account=$SCHOOL_WORKGROUP\\register password=register
