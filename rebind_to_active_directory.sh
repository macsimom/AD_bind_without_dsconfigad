#!/bin/bash

#
# MIT License
#
# Copyright (c) 2022 Simon Andersen
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# set -x

BASEDIR="/Users/Shared"
cd "$BASEDIR"

export SVCACCOUNT="$(/usr/libexec/PlistBuddy -c "Print :SVCAccountName" ADInfo.plist)"
export SVCACCOUNTP="$(/usr/libexec/PlistBuddy -c "Print :SVCPassword" ADInfo.plist)"

export DOMAINFQDN=$(/usr/libexec/PlistBuddy -c "Print :DomainFQDN" ADInfo.plist)
export DOMAINNAME=$(/usr/libexec/PlistBuddy -c "Print :DomainName" ADInfo.plist)
export KERBEROSREALM=$(/usr/libexec/PlistBuddy -c "Print :KerberosRealm" ADInfo.plist)
export COMPUTERNAME=$(/usr/libexec/PlistBuddy -c "Print :Computername" ADInfo.plist)
export COMPUTEROU=$(/usr/libexec/PlistBuddy -c "Print :ComputerOU" ADInfo.plist)

while [[ -z "$LDAPSERVER" ]]; do
# possibly wait forever
LDAPSERVER=$(dig -t SRV _ldap._tcp.$DOMAINFQDN +short |awk '{print $NF}'|sed -E -n -e 's/\.$//p')
done

LDAPBASE=$(ldapsearch -h $LDAPSERVER -x -D "${SVCACCOUNT}@$DOMAINFQDN" -w "$SVCACCOUNTP" -s base -LLL '(objectClass=*)' defaultNamingContext|awk '/^defaultNamingContext: / {print $NF; exit}')

if [[ -z "$COMPUTEROU" ]]; then
	export COMPUTEROU="CN=Computers,$LDAPBASE"
fi
    
OPERATINGSYSTEM="$(sw_vers -productName)"
OPERATINGSYSTEMVERSION="$(sw_vers -productVersion) ($(sw_vers -buildVersion))"
SERIALNUMBER=$(/usr/libexec/PlistBuddy -c "Print :IORegistryEntryChildren:0:IOPlatformSerialNumber" /dev/stdin <<<$(ioreg -l -a))


HOSTENTRIES=$(ldapsearch -H ldap://$LDAPSERVER -x -D "${SVCACCOUNT}@$DOMAINFQDN" -w "$SVCACCOUNTP" -b "$LDAPBASE" -s sub "(cn=${COMPUTERNAME})" sAMAccountName |awk '/numEntries: / {print $NF}')
HOSTENTRIES="${HOSTENTRIES:=0}"

if [[ $HOSTENTRIES -gt 0 ]]; then
    echo "WARNING: $COMPUTERNAME already exists"
else
    echo "We should create $COMPUTERNAME..."
    
    ldapmodify -H ldap://$LDAPSERVER -x -D "${SVCACCOUNT}@$DOMAINFQDN" -w "$SVCACCOUNTP" <<EOF
dn: CN=$COMPUTERNAME,$COMPUTEROU
changetype: add
objectClass: computer
objectClass: organizationalPerson
objectClass: person
objectClass: top
objectClass: user
instanceType: 4
objectCategory: CN=Computer,CN=Schema,CN=Configuration,$LDAPBASE
cn: ${COMPUTERNAME}
sAMAccountName: ${COMPUTERNAME}\$
name: ${COMPUTERNAME}
description: Manually bound via script
operatingSystem: $OPERATINGSYSTEM
operatingSystemVersion: $OPERATINGSYSTEMVERSION
userAccountControl: 69632
dNSHostName: ${COMPUTERNAME}.$DOMAINFQDN

EOF

if [[ $? != 0 ]]; then
    echo "Failed to create computer object"
    exit 1
fi

fi

COMPUTERDN=$(ldapsearch -H ldap://$LDAPSERVER -x -D "${SVCACCOUNT}@$DOMAINFQDN" -w "$SVCACCOUNTP" -b "$LDAPBASE" -s sub "(cn=$COMPUTERNAME)" sAMAccountName|awk '/^dn: / {print $NF; exit}')

if [[ -n "$SERIALNUMBER" ]]; then
    ldapmodify -H ldap://$LDAPSERVER -x -D "${SVCACCOUNT}@$DOMAINFQDN" -w "$SVCACCOUNTP" <<EOF
dn: $COMPUTERDN
changetype: modify
replace: serialNumber
serialNumber: $SERIALNUMBER

EOF
fi





HOSTPASSWORD="$(date | openssl sha256 |openssl base64|head -c17)"
security delete-generic-password -l "/Active Directory/$DOMAINNAME" -a "$COMPUTERNAME\$" -s "/Active Directory/$DOMAINNAME" "/Library/Keychains/System.keychain"
security add-generic-password -l "/Active Directory/$DOMAINNAME" -a "$COMPUTERNAME\$" -s "/Active Directory/$DOMAINNAME" -A -w "$HOSTPASSWORD" "/Library/Keychains/System.keychain"



## Set the password for the computer account

#HOSTPASSWORD="$(date | openssl sha256 |openssl base64|head -c17)"
#HOSTPASSWORD="$(security find-generic-password -l "/Active Directory/$DOMAINNAME" -w)"

EXPECTSCRIPT=$(mktemp -t XXXexpect) 
cat <<EOF > "$EXPECTSCRIPT"
spawn kpasswd --admin-principal=${SVCACCOUNT}@$KERBEROSREALM $COMPUTERNAME\$@$KERBEROSREALM
expect "${SVCACCOUNT}@$KERBEROSREALM's Password:"
send -- "$SVCACCOUNTP\r"
expect "New password for $COMPUTERNAME\$@$KERBEROSREALM:"
send -- "$HOSTPASSWORD\r"
expect "Verify password - New password for $COMPUTERNAME\$@$KERBEROSREALM:"
send -- "$HOSTPASSWORD\r"
expect "Success"
interact
EOF
echo "Attempting to set password for $COMPUTERNAME@$KERBEROSREALM using ${SVCACCOUNT}@$KERBEROSREALM credentials..."
/usr/bin/expect -f "$EXPECTSCRIPT"
KPASSWDRESULT=$?
rm "$EXPECTSCRIPT"
if [[ $KPASSWDRESULT != 0 ]]; then
    echo "Failed to set password for $COMPUTERNAME"
    exit 1
fi

#echo "Password for $COMPUTERNAME@$KERBEROSREALM:"
#echo "$HOSTPASSWORD"

dscl localhost append /Search CSPSearchPath "/Active Directory/$DOMAINNAME/All Domains"

if [[ -e '/Library/LaunchDaemons/local.rebind_to_active_directory.plist' ]]; then
	rm -f '/Library/LaunchDaemons/local.rebind_to_active_directory.plist'
fi
launchctl remove local.rebind_to_active_directory
