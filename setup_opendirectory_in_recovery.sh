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

BASEDIR="/Volumes/Macintosh HD"
cd "$BASEDIR/Users/Shared"
export DOMAINFQDN=$(/usr/libexec/PlistBuddy -c "Print :DomainFQDN" ADInfo.plist)
export DOMAINNAME=$(/usr/libexec/PlistBuddy -c "Print :DomainName" ADInfo.plist)
export KERBEROSREALM=$(/usr/libexec/PlistBuddy -c "Print :KerberosRealm" ADInfo.plist)
export COMPUTERNAME=$(/usr/libexec/PlistBuddy -c "Print :Computername" ADInfo.plist)



cp DOMAIN.plist $DOMAINNAME.plist
sed -i -E -e  "s/DOMAINFQDN/$DOMAINFQDN/g" $DOMAINNAME.plist
sed -i -E -e  "s/DOMAINNAME/$DOMAINNAME/g" $DOMAINNAME.plist
sed -i -E -e  "s/KERBEROSREALM/$KERBEROSREALM/g" $DOMAINNAME.plist
sed -i -E -e  "s/COMPUTERNAME/$COMPUTERNAME/g" $DOMAINNAME.plist

mkdir -p "$BASEDIR/Library/Preferences/OpenDirectory/Configurations/Active Directory"
cp -f $DOMAINNAME.plist "$BASEDIR/Library/Preferences/OpenDirectory/Configurations/Active Directory/$DOMAINNAME.plist"

touch "$BASEDIR/Users/Shared/rebind_to_active_directory.log"
chmod 666 "$BASEDIR/Users/Shared/rebind_to_active_directory.log"
cat > "$BASEDIR/Library/LaunchDaemons/local.rebind_to_active_directory.plist" <<EOPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>Label</key>
        <string>local.rebind_to_active_directory</string>
        <key>ProgramArguments</key>
        <array>
        	<string>/bin/bash</string>
			<string>/Users/Shared/rebind_to_active_directory.sh</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
		<key>StandardOutPath</key>
        <string>/Users/Shared/rebind_to_active_directory.log</string>
        <key>StandardErrorPath</key>
        <string>/Users/Shared/rebind_to_active_directory.log</string>
</dict>
</plist>
EOPLIST
echo "Rebooting in 5 seconds..."
sleep 5
reboot
