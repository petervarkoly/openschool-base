#!/bin/bash
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
while read a
do
  if [ -z "$G" ]; then
    G=$( echo $a | grep group )
  fi
done
if [ -z "$G" ]; then
        exit
fi
test -e /var/run/import_user.pid && exit
nscd -i group
nscd -i passwd
ssh proxy "/etc/init.d/squid reload"
