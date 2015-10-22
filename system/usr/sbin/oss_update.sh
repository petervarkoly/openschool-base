echo 'DATE=`/usr/share/oss/tools/oss_date.sh`
. /etc/profile.d/profile.sh
echo "/var/log/OSS-UPDATE-$DATE" > /var/adm/oss/update-started
zypper --no-gpg-checks --gpg-auto-import-keys -n up --auto-agree-with-licenses  &> /var/log/OSS-UPDATE-$DATE
if [ $? ]; then 
echo "You have to reboot your OSS-server!
Bitte starten Sie Ihren OSS-Server neu!" > /var/adm/oss/must-restart
fi
/etc/cron.daily/oss.list-updates
rm /var/adm/oss/update-started
' | at now
