Place the files in ```/Users/Shared``` on the OS drive

Modify ```ADInfo.plist``` to your Active Directory

Boot in recovery (if not already)

run ```/Volumes/Macintosh HD/Users/Shared/setup_opendirectory_in_recovery.sh```

Reboot the Mac

Mac is bound despite [KB5008380](https://support.microsoft.com/en-us/topic/kb5008380-authentication-updates-cve-2021-42287-9dafac11-e0d0-4cb8-959a-143bd0201041) having ```PacRequestorEnforcement``` set to 2