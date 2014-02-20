#!/usr/bin/python
#   importAccounts - Import user and group data for a directory server
#   Copyright (C) 2008 Gordon Messmer <gordon dragonsdawn net>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

import csv
import sets
import sys

import ldap
import ldap.modlist
import ldif

users = {}
groups = {}
passwd = '/etc/passwd'
shadow = '/etc/shadow'
smbpasswd = '/etc/samba/smbpasswd'
group = '/etc/group'
gshadow = '/etc/gshadow'
sambaDomainSID = 'S-1-5-21-5555555-55555555-55555555'

caCertFile = None
ldapUri = 'ldap://directory.example.com'
baseDN = 'dc=example,dc=com'
ldapMergeIgnores = ['cn', 'sn', 'givenName', 'userPassword']


class ImportError(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)


class SkipOutput(ImportError):
    pass


class User:
    def __init__(self, user):
        self.uid = user
        self.userPassword = None
        self.uidNumber = None
        self.gidNumber = None
        self.gecos = None
        self.homeDirectory = None
        self.loginShell = None
        self.shadowLastChange = None
        self.shadowMin = None
        self.shadowMax = None
        self.shadowWarning = None
        self.shadowInactive = None
        self.shadowExpire = None
        self.shadowFlag = None
        self.sambaLMPassword = None
        self.sambaNTPassword = None
        self.sambaAcctFlags = None
        self.sambaPwdLastSet = None


class Group:
    def __init__(self, group):
        self.cn = group
        self.userPassword = None
        self.gidNumber = None
        self.members = []


class unixpwdDialect(csv.Dialect):
    delimiter = ':'
    doublequote = False
    escapechar = '\\'
    lineterminator = '\n'
    quotechar = '"'
    quoting = csv.QUOTE_NONE
    skipinitialspace = False


def ldapConnect():
    if(caCertFile):
        ldap.set_option(ldap.OPT_X_TLS_CACERTFILE, caCertFile)
    server = ldap.initialize(ldapUri)
    server.protocol_version = ldap.VERSION3
    return server


def ldapSearch(filter, attributes=None, server=None):
    """Search the directory."""
    if not server:
        server = ldapConnect()
    scope = ldap.SCOPE_SUBTREE
    return server.search_s(baseDN, scope, filter, attributes)


def getUser(user):
    if not user in users:
        users[user] = User(user)
    return users[user]


def getGroup(group):
    if not group in groups:
        groups[group] = Group(group)
    return groups[group]


def inFilterPasswd():
    try:
        reader = csv.reader(open(passwd, 'r'), 'unixpwd')
    except IOError:
        sys.stderr.write('Password file not readable.\n')
        sys.exit(66)
    for row in reader:
        userEnt = getUser(row[0])
        (userEnt.userPassword,
         userEnt.uidNumber,
         userEnt.gidNumber,
         userEnt.gecos,
         userEnt.homeDirectory,
         userEnt.loginShell) = row[1:]


def inFilterShadow():
    try:
        reader = csv.reader(open(shadow, 'r'), 'unixpwd')
    except IOError:
        sys.stderr.write('Shadow file not readable.\n')
        sys.exit(66)
    for row in reader:
        userEnt = getUser(row[0])
        (userEnt.userPassword,
         userEnt.shadowLastChange,
         userEnt.shadowMin,
         userEnt.shadowMax,
         userEnt.shadowWarning,
         userEnt.shadowInactive,
         userEnt.shadowExpire,
         userEnt.shadowFlag) = row[1:]


def addGroupMembers(groupEnt, members):
    if members:
        groupMembers = members.split(',')
        for member in groupMembers:
            if member not in groupEnt.members:
                groupEnt.members.append(member)


def inFilterGroup():
    try:
        reader = csv.reader(open(group, 'r'), 'unixpwd')
    except IOError:
        sys.stderr.write('Group password file not readable.\n')
        sys.exit(66)
    for row in reader:
        groupEnt = getGroup(row[0])
        (groupEnt.userPassword,
         groupEnt.gidNumber) = row[1:3]
        addGroupMembers(groupEnt, row[3])


def inFilterGshadow():
    try:
        reader = csv.reader(open(gshadow, 'r'), 'unixpwd')
    except IOError:
        sys.stderr.write('Group shadow password file not readable.\n')
        sys.exit(66)
    for row in reader:
        groupEnt = getGroup(row[0])
        groupEnt.userPassword = row[1]
        # We don't convert admins
        addGroupMembers(groupEnt, row[3])


def inFilterSmbpasswd():
    try:
        reader = csv.reader(open(smbpasswd, 'r'), 'unixpwd')
    except IOError:
        sys.stderr.write('Samba password file not readable.\n')
        sys.exit(66)
    for row in reader:
        userEnt = getUser(row[0])
        if userEnt.uidNumber != row[1]:
            continue
        (userEnt.sambaLMPassword,
         userEnt.sambaNTPassword,
         userEnt.sambaAcctFlags,
         userEnt.sambaPwdLastSet) = row[2:6]


def outFilterUserPassword(entry):
    if hasattr(entry, 'userPassword') and entry.userPassword:
        entry.userPassword = '{CRYPT}%s' % entry.userPassword


def outFilterUserValid(userEnt):
    if not (userEnt.uid and userEnt.uidNumber and userEnt.gidNumber
            and userEnt.homeDirectory):
        raise SkipOutput('information for %s is incomplete' % userEnt.uid)


def outFilterUid(userEnt):
    if int(userEnt.uidNumber) < 500:
        raise SkipOutput('uid indicates local system account')


def ldifAddAttribute(out, entry, attribute):
    if getattr(entry, attribute):
        out[attribute] = [getattr(entry, attribute)]


def outFilterUserComposeLdif(userEnt):
    out = {}
    userEnt.dn = 'uid=%s,ou=People,%s' % (userEnt.uid, baseDN)
    out['objectClass'] = ['posixAccount', 'shadowAccount', 'inetOrgPerson']
    for attr in ('uid', 'userPassword', 'uidNumber', 'gidNumber', 'gecos',
                 'homeDirectory', 'loginShell',
                 'shadowLastChange', 'shadowMin', 'shadowMax', 'shadowWarning',
                 'shadowInactive', 'shadowExpire', 'shadowFlag'):
        ldifAddAttribute(out, userEnt, attr)
    if userEnt.gecos:
        gecos = userEnt.gecos
    else:
        gecos = userEnt.uid
    gfields = gecos.split(',')
    out['cn'] = [gfields[0]]
    names = gfields[0].split()
    out['sn'] = [names[-1]]
    if names[0:-1]:
        out['givenName'] = [' '.join(names[0:-1])]
    if(sambaDomainSID
       and (userEnt.sambaAcctFlags or userEnt.sambaLMPassword
            or userEnt.sambaNTPassword or userEnt.sambaPwdLastSet)):
        out['objectClass'].append('sambaSamAccount')
        out['sambaSID'] = ['%s-%d' % (sambaDomainSID,
                                      int(userEnt.uidNumber) * 2 + 1000)]
        for attr in ('sambaLMPassword', 'sambaNTPassword', 'sambaAcctFlags',
                     'sambaPwdLastSet'):
            ldifAddAttribute(out, userEnt, attr)
    userEnt.ldif = out


def outFilterUserLdapScrub(entry):
    filter = 'uid=%s' % (entry.uid,)
    outFilterLdapScrub(entry, filter)


def outFilterGroupValid(groupEnt):
    if not (groupEnt.cn and groupEnt.gidNumber):
        raise SkipOutput('information for %s is incomplete' % groupEnt.cn)


def outFilterGid(groupEnt):
    if int(groupEnt.gidNumber) < 500:
        raise SkipOutput('gid indicates local system group')


def outFilterGroupComposeLdif(groupEnt):
    out = {}
    groupEnt.dn = 'cn=%s,ou=Groups,%s' % (groupEnt.cn, baseDN)
    out['objectClass'] = ['posixGroup']
    for attr in ('cn', 'gidNumber'):
        ldifAddAttribute(out, groupEnt, attr)
    if groupEnt.members:
        out['objectClass'].append('groupOfNames')
        out['memberUid'] = []
        out['member'] = []
        for member in groupEnt.members:
            out['memberUid'].append(member)
            out['member'].append('uid=%s,ou=People,%s' % (member, baseDN))
    if(sambaDomainSID):
        out['objectClass'].append('sambaGroupMapping')
        out['sambaGroupType'] = ['2']
        out['sambaSID'] = ['%s-%d' % (sambaDomainSID,
                                      int(groupEnt.gidNumber) * 2 + 1001)]
    groupEnt.ldif = out


def outFilterGroupLdapScrub(entry):
    filter = 'cn=%s' % (entry.cn,)
    outFilterLdapScrub(entry, filter)


def outFilterLdapScrub(entry, ldapFilter):
    attributes = entry.ldif.keys()
    ldapResult = ldapSearch(ldapFilter, attributes=attributes)
    if len(ldapResult) is not 1:
        entry.ldif = ldap.modlist.addModlist(entry.ldif)
        return
    entry.dn = ldapResult[0][0]
    for attr in ldapMergeIgnores:
        if attr in entry.ldif:
            del entry.ldif[attr]
    for attr in ldapResult[0][1]:
        if attr in entry.ldif:
            vals = sets.Set(entry.ldif[attr])
            newvals = list(vals.union(ldapResult[0][1][attr]))
            entry.ldif[attr] = newvals
        else:
            entry.ldif[attr] = ldapResult[0][1][attr]
    entry.ldif = ldap.modlist.modifyModlist(ldapResult[0][1], entry.ldif)


def outFilterWriteLdif(entry):
    writer=ldif.LDIFWriter(sys.stdout)
    writer.unparse(entry.dn, entry.ldif)


csv.register_dialect('unixpwd', unixpwdDialect)

userInFilters = (inFilterPasswd, inFilterShadow, inFilterSmbpasswd)
userOutFilters = (outFilterUserValid, outFilterUid, outFilterUserPassword,
                  outFilterUserComposeLdif, outFilterUserLdapScrub, outFilterWriteLdif)

groupInFilters = (inFilterGroup, inFilterGshadow)
groupOutFilters = (outFilterGroupValid, outFilterGid, outFilterUserPassword,
                   outFilterGroupComposeLdif, outFilterGroupLdapScrub, outFilterWriteLdif)

for filter in userInFilters:
    filter()
for filter in groupInFilters:
    filter()

for user in users.values():
    try:
        for filter in userOutFilters:
            filter(user)
    except SkipOutput, cause:
        sys.stderr.write('%s\n' % cause)
        continue
for group in groups.values():
    try:
        for filter in groupOutFilters:
            filter(group)
    except SkipOutput, cause:
        sys.stderr.write('%s\n' % cause)
        continue
