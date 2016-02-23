#Create ClaxxAccount to access all ldap attributes
. /etc/sysconfig/ldap
. /etc/sysconfig/schoolserver
LDAPBASE=`echo $BIND_DN | sed 's/cn=Administrator,//'`
PASSWORD=$(mktemp -u XXXXXXXX)

# Check if account already exists:
EXISTS=$( oss_ldapsearch cn=claxsss )
if [ $EXISTS ]
then
   exit 1
fi
# Add daemon admin
echo "dn: ou=daemonadmins,$LDAPBASE
objectClass: organizationalUnit
ou: daemonadmins" | /usr/sbin/oss_ldapadd &> /dev/null

echo "dn: cn=claxss,ou=daemonadmins,$LDAPBASE
objectClass: top
objectClass: person
userPassword: $PASSWORD
cn: claxss
sn: Account for reading all attributes" | /usr/sbin/oss_ldapadd &> /dev/null

#Add new acls
echo "dn: olcDatabase={1}hdb,cn=config
add: olcAccess
olcAccess: {2}to dn.subtree="$LDAPBASE" by dn.exact=\"cn=claxss,ou=daemonadmins,$LDAPBASE\" read by * read break
" | ldapmodify -Y external -H ldapi:/// &> /dev/null

echo $PASSWORD cn=claxss,ou=daemonadmins,$LDAPBASE

