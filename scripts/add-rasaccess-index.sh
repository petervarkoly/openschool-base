echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: o eq" | ldapmodify -Y external -H ldapi:/// 

