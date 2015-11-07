echo "dn: olcDatabase={1}hdb,cn=config
delete: olcDbIndex
olcDbIndex: configurationValue eq,sub" | ldapmodify -Y external -H ldapi:///

