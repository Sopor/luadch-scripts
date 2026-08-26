# My own modified Luadch scripts!

## If you want to know more about the changes you can read the changelog inside every script.

##### [etc_chatlog.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_chatlog.lua)
 -  v1.6: replacment for the original etc_chatlog.lua<br />
           - added etc_nospam.lua is now included to prevent blocked messages to be sent to history log<br />
           - added ptx_mainchatblockclean.lua is now included and will clear history log after a main chat clean<br />
         **NOTE: if you are running etc_nospam.lua and/or ptx_mainchatblockclean.lua you need to remove them from cfg.tbl**<br />
           - added blocks message with too many characters<br />
           - added blocks message with too many rows (line breaks)<br />
           - added tell level 60 and above when someone gets blocked<br />
           - added send logs and warnings to Hubbot and/or OPChat<br />
           - fixed command usage will now show different commands for users and ops<br />
         **NOTE: this should work with Luadch 2.23, 2.24 and 3.1.x**

##### [etc_mainecho.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_mainecho.lua)
 - v0.6: a trigger bot for main<br />
           - added cooldown option for same trigger<br />
           - added option to set minlevel to use RC bot sleep

##### [etc_masspmoffline.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_masspmoffline.lua)
 - v1.4: send masspm to offline users and to a specific level and also set an expiration date on the message<br />
           - sends online PMs without requiring the ONLINE mode or a duration<br />
           - supports minute, hour, day, week, and month message durations

##### [etc_motd.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_motd.lua)
 - v0.08: this script sends a message to users after login and it can be triggered manually<br />
           - added command to show motd<br />
           - added right-click menu<br />
           - added help

##### [etc_requests.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_requests.lua)
 -  v0.19: request-bot<br />
           - fixed attempt to call a nil value

##### [etc_setemail.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/etc_setemail.lua)
 - v1.6: this script will ask the user at login to save an email address<br />
           - added check, show and remove email addresses that doesn't have an account anymore

##### [ptx_freshstuff.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/ptx_freshstuff.lua)
 - v0.141: multifunctional release-bot<br />
          - oops i forgot to include the updated ptx_freshstuff_categories.dat :/

##### [usr_hubs.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/usr_hubs.lua)
 - v0.14: this script checks the hub count of a user<br />
           - now only compatible with Luadch 3.x and higher

##### [usr_upload_speed.lua](https://github.com/Sopor/luadch-scripts/tree/main/7-zip/usr_upload_speed.lua)
 - v0.8: this script compares the speed prefix and Upload Speed from INF US field<br />
           **NOTE: should be used together with the included etc_trafficmanager.lua v2.2.3**<br />
           - using CID to remove old blocks after a user got a new prefix<br />
           - not announce a blocked user again after +reload<br />
           - added ban_interval<br />
           - cleaning up some unnecessary code

## Have you made any Luadch scripts you want to share? Contact me and I will share your Luadch scripts here!
