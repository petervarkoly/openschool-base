rcldap stop 
mv /var/lib/ldap /var/lib/ldap-back 
mkdir -p /var/lib/ldap 
cp -p /var/lib/ldap-back/DB_CONFIG /var/lib/ldap 
db_dump /var/lib/ldap-back/id2entry.bdb > id2entry.dump 
db_dump /var/lib/ldap-back/dn2id.bdb > dn2id.dump 
db_load -f id2entry.dump /var/lib/ldap/id2entry.bdb 
db_load -f dn2id.dump /var/lib/ldap/dn2id.bdb 
chown -R ldap /var/lib/ldap 
slapindex
rcldap start

