# Background

Microsoft changed Kerberos PAC handling with update [KB5008380](https://support.microsoft.com/en-us/topic/kb5008380-authentication-updates-cve-2021-42287-9dafac11-e0d0-4cb8-959a-143bd0201041) and it seems to break binding Macs to Active Directory using ```dsconfigad```

Initial suggestions on how to bind if it's still required range from "don't activate full enforcement" to "forget about binding" neither of which seem acceptable.

So I tried manually modifying the opendirectory plist file that constitutes an AD bind and placing it in the appropriate location in tandem with adding valid machine credentials to the System keychain in order to configure the Mac as bound. Fake it till you make it.

The procedure boils down to:

* Modify the opendirectory plist file and put in place
* Create a computer object in AD using ldap utils
* Add the computer credentials to the System keychain
* Set the computer object credentials to the above in AD using `kpasswd`

The Mac and AD are then in agreement and the Mac is for all intents and purposes bound. Specific AD plug-in configuration can then be set with `dsconfigad`

* I've tested logging on as an AD network user and having it be cached as a local account.
* Periodic computer password rotation (`dsconfig -passinterval`) also appears to function as expected.
* Configuring sshd on the Mac to accept GSSAPI credentials also appears to work as expected.

# How to

Place the files in ```/Users/Shared``` on the OS drive

Modify ```ADInfo.plist``` to your Active Directory settings.

```SVCAccountName``` and ```SVCPassword``` are the credentials of an AD user with the privileges to bind a machine to the domain.

Boot in recovery (if not already)

run ```/Volumes/Macintosh HD/Users/Shared/setup_opendirectory_in_recovery.sh```

Reboot the Mac

Mac is bound despite [KB5008380](https://support.microsoft.com/en-us/topic/kb5008380-authentication-updates-cve-2021-42287-9dafac11-e0d0-4cb8-959a-143bd0201041) having ```PacRequestorEnforcement``` set to 2

# To Do

* Clean up (you should definitely delete the ADInfo.plist containing the credentials when done)
