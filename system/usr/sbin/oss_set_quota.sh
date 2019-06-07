#!/bin/bash -x
user=$1
quota=$2

EXT3=$( mount | grep "on /home type ext3" )
if [ "$EXT3" ]; then
        fquota=$((quota*1024))
        /usr/sbin/setquota -u $user $fquota $fquota 0 0 /home
else
        bhard=$((quota+quota/10))
        xfs_quota -x -c "limit -u bsoft=${quota}m bhard=${bhard}m $user" /home
fi
