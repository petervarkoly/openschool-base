echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: rasAccess eq" | ldapmodify -Y external -H ldapi:/// 


echo "dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: o eq" | ldapmodify -Y external -H ldapi:///


