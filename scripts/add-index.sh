echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: $1 $2" | ldapmodify -Y external -H ldapi:///

