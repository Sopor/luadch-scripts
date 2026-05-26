# My own modified Luadch scripts!

## If you want to know more about the changes you can read the changelog inside every script.

##### [etc_chatlog.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_chatlog.lua)
 - v1.51: original etc_chatlog that now includes etc_nospam and ptx_mainchatblockclean
           - fixed: temporary fix for "bad argument #1 to 'byte' (string expected, got nil)"

 -  v1.6: now includes etc_nospam.lua and ptx_mainchatblockclean.lua
           - added: etc_nospam.lua is now included to prevent blocked messages to be sent to history log
           - added: ptx_mainchatblockclean.lua is now included and will clear history log after a main chat clean
         **NOTE: if you are running etc_nospam.lua and/or ptx_mainchatblockclean.lua you need to remove them from cfg.tbl**
           - added: blocks message with too many characters
           - added: blocks message with too many rows (line breaks)
           - added: tell level 60 and above when someone gets blocked
           - added: send logs and warnings to Hubbot and/or OPChat
           - fixed: command usage will now show different commands for users and ops
         **NOTE: this should work with Luadch 2.23 and 2.24**

##### [etc_mainecho.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_mainecho.lua)
 -  v0.5: a trigger bot for main
           - changed: now only compatible with Luadch 3.x and higher

##### [etc_motd.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_motd.lua)
 - v0.08: this script sends a message to users after login and it can be triggered manually
           - added: command to show motd
           - added: rightclick
           - added: help

##### [etc_requests.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_requests.lua)
 -  v0.16: request-bot
           - added: group list ban
 -  v0.17:
           - changed: now only compatible with Luadch 3.x and higher
 -  v0.18:
           - changed: command registration to etc_hubcommands


##### [etc_setemail.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_setemail.lua)
 -  v1.2: this script will ask the user at login to save an email address
           - added: right-click menus for OP
 -  v1.3:
           - added: option to show both english and/or swedish messages
           - added: if the user change username it will automatically update the etc_setemail.tbl
 -  v1.4
           - changed command registration to etc_hubcommands
           - foolproofing the pattern for email addresses
 -  v1.5
           - if the user change CID it will automatically update the etc_setemail.tbl

##### [ptx_freshstuff.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/ptx_freshstuff.lua)
 - v0.12: multifunctional release-bot
           - changed: better explanation in the right click menu for opt-out/in

##### [usr_hubs.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/usr_hubs.lua)
 - v0.13: this script checks the hub count of a user
           - added: shows user's IP address in OpChat when exceeded user's hub limit
 - v0.14:
           - fixed: now only compatible with Luadch 3.x and higher

##### [usr_upload_speed.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/usr_upload_speed.lua)
 - v0.6: this script compares the speed prefix and Upload Speed from INF US field
         this is to prevent users from using the built-in limiter
           - added: DC++/ApexDC++/EiskaltDC++, but they need to use the limiter for speeds that doesn't exists in the line speed

## Have you made any Luadch scripts you want to share? Contact me and I will share your Luadch scripts here!
