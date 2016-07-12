DATE=$( /usr/share/oss/tools/oss_date.sh )
. /etc/profile.d/profile.sh
echo "/var/log/OSS-UPDATE-$DATE" > /var/adm/oss/update-started
zypper --no-gpg-checks --gpg-auto-import-keys -n up --auto-agree-with-licenses  2>&1 | tee /var/log/OSS-UPDATE-$DATE
/etc/cron.daily/oss.list-updates
rm /var/adm/oss/update-started

