--[[

    etc_setemail.lua by Sopor

            - this script will ask the user at login to save an email address
            - the user can choose between saving the email address or ignore the message
            - the user will be reminded again after 7 days (adjustable) at login
            - if the user still doesn’t want to provide an email address, they can ignore it a second time and the script won’t bother them again
            - because users sometimes change their email address, the system will ask them to verify it every 12 months (adjustable)
    usage:
        [+!#]setemail <emailaddress>
        [+!#]setemail ignore
        [+!#]setemail verify
        [+!#]setemail delete

 op usage:
        [+!#]setemail add <nick> <emailaddress>
        [+!#]setemail showop <nick>
        [+!#]setemail deleteop <nick>
        [+!#]setemail verifyop <nick>
        [+!#]setemail ignoreop <nick>
        [+!#]setemail whois <emailaddress>
        [+!#]setemail showall

        v1.5
            - if the user change CID it will automatically update the etc_setemail.tbl

        v1.4
            - changed command registration to etc_hubcommands
            - foolproofing the pattern for email addresses

        v1.3
            - added option to show both english and/or swedish messages
            - if the user change username it will automatically update the etc_setemail.tbl

        v1.2
            - added right-click menus for OP

        v1.1
            - remind users to set an email address
            - add / show / delete / whois commands

        v1.0
            - first release

]]--

--------------------
-- CONFIG
--------------------

local scriptname = "etc_setemail"
local scriptversion = "1.5"

local data_file = "scripts/data/etc_setemail.tbl"

-- reminder for users WITHOUT an email address saved, there will be a second reminder if they use ignore
-- default: 7 days = 10080 minutes
local reminder_minutes = 10080

-- reminder for users WITH an email address to verify it
-- default: 12 months = 525600 minutes
local verify_reminder = 525600

-- choose message language between english and/or swedish: "en", "sv", or "both" | OP messages are always in english
-- default: english
local showlang = "en"

-- users at this level and above can run OP commands
local oplevel = 60

-- users below this level will not see any right‑click menu or be able to run this command
local minlevel = 20

-- who will be asked to save an email address at login
local ask_level = {
    [ 0 ]   = 0, -- unreg
    [ 10 ]  = 0, -- guest
    [ 20 ]  = 1, -- reg
    [ 30 ]  = 1, -- vip
    [ 40 ]  = 1, -- svip
    [ 50 ]  = 0, -- server
    [ 55 ]  = 0, -- sbot
    [ 60 ]  = 0, -- operator
    [ 70 ]  = 0, -- supervisor
    [ 80 ]  = 0, -- admin
    [ 100 ] = 0, -- hubowner
}

--------------------
-- MESSAGES
--------------------

local msg_header = "\n=== EMAIL ========================================================================================\n"

local msg_footer = "\n\n======================================================================================== EMAIL ===\n"

local msg_noentry = "\tPlease save your email address in the hub!\n\t" ..
                    "If this hub ever crashes, moves or have major issues the hubowner have no way to contact you without your email address!\n\t" ..
                    "If you want us to have your email address, type here in main chat: [+!#]setemail <emailaddress>\n\t" ..
                    "You can also ignore this message by typing: [+!#]setemail ignore\n\t" ..
                    "All the commands are also available in the right-click menu in the hub tab!\n\t" ..
                    "Help: When you see [+!#]setemail, the square brackets indicate that you can use any of those characters to trigger the command\n\t" ..
                    "For example: +setemail firstname.lastname@example.com"
local msgsv_noentry = "\tSpara gärna din e-postadress i hubben!\n\t" ..
                      "Om den här hubben kraschar, flyttas eller får problem har hubbägaren inget sätt att kontakta dig utan din e-postadress!\n\t" ..
                      "Om du vill att vi ska ha din e-postadress, skriv här i huvudchatten: [+!#]setemail <e-postadress>\n\t" ..
                      "Du kan också ignorera det här meddelandet genom att skriva: [+!#]setemail ignore\n\t" ..
                      "Alla kommandon finns också tillgängliga i högerklicksmenyn på hubbfliken!\n\t" ..
                      "Hjälp: När du ser [+!#]setemail anger hakparenteserna att du kan använda ett av de tecknen för att trigga kommandot\n\t" ..
                      "Till exempel: +setemail fornamn.efternamn@exempel.se"

local msg_denied = "You are not allowed to use this command."
local msgsv_denied = "Du har inte tillåtelse att använda det här kommandot."

local msg_noemail = "[ EMAIL ] --> You have no email address saved."
local msgsv_noemail = "[ EMAIL ] --> Du har ingen sparad e-postadress."

local msg_showemail = "[ EMAIL ] --> Your email address: "
local msgsv_showemail = "[ EMAIL ] --> Din e-postadress: "

local msg_noemailtodel = "[ EMAIL ] --> You have no email address to delete."
local msgsv_noemailtodel = "[ EMAIL ] --> Du har ingen e-postadress att ta bort."

local msg_delcancel = "[ EMAIL ] --> Deletion cancelled. To delete your email, type: [+!#]setemail delete yes"
local msgsv_delcancel = "[ EMAIL ] --> Borttagning avbruten. För att ta bort din e-postadress, skriv: [+!#]setemail delete yes"

local msg_delsuccess = "[ EMAIL ] --> Your email address has been deleted: "
local msgsv_delsuccess = "[ EMAIL ] --> Din e-postadress har tagits bort: "

local msg_rempermdis = "[ EMAIL ] --> Email reminders have been permanently disabled."
local msgsv_rempermdis = "[ EMAIL ] --> E-postpåminnelser är permanent inaktiverade."

local msg_remoncemore = "[ EMAIL ] --> Email reminder ignored. You will receive one more reminder later in case you change your mind."
local msgsv_remoncemore = "[ EMAIL ] --> E-postpåminnelsen ignorerades. Du kommer att få en påminnelse senare i fall du har ångrat dig."

local msg_verified = "[ EMAIL ] --> Your email address has been verified: "
local msgsv_verified = "[ EMAIL ] --> Din e-postadress har verifierats: "

local msg_invalid = "[ EMAIL ] --> Invalid email address format."
local msgsv_invalid = "[ EMAIL ] --> Ogiltigt format på e-postadressen."

local msg_op_mustonline = "[ EMAIL ] --> User must be online to set an email address."

local msg_op_usage = "Usage: [+!#]setemail add <nick> <emailaddress>"

local msg_op_emailfor = "[ EMAIL ] --> Email address for "

local msg_op_emailfor2 = " has been set to: "

local msg_op_emaildeleted = " has been deleted: "

local msg_op_verified = " has been verified: "

local msg_op_ignored = " has been ignored."

local msg_op_noemailfor = "[ EMAIL ] --> No email address found for user: "

local msg_op_noemailfound = "[ EMAIL ] --> No email address found for user: "

local msg_op_belongsto = "[ EMAIL ] --> Email address belongs to: "

local msg_op_nouserfound = "[ EMAIL ] --> No user found for email address: "

local msg_emailsaved = "[ EMAIL ] --> Your email address has been saved: "
local msgsv_emailsaved = "[ EMAIL ] --> Din e-postadress har sparats: "

local help_title = "etc_setemail.lua"

local help_usage = "Usage: [+!#]setemail <emailaddress> / [+!#]setemail show / [+!#]setemail delete / [+!#]setemail verify"

local help_desc = "Lets the user save their email address"

local help_op_title = "etc_setemail.lua - Operators"

local help_op_usage = "Usage: [+!#]setemail add <nick> <emailaddress> / [+!#]setemail showop <nick> / [+!#]setemail deleteop <nick> /" ..
                      "[+!#]setemail verifyop <nick> / [+!#]setemail ignoreop <nick> / [+!#]setemail whois <emailaddress> / [+!#]setemail showall"

local help_op_desc = "Lets the user save their email address"

local msg_lastremtosave = "This is the last reminder to save your email address.\n" ..
                          "Use '[+!#]setemail <emailaddress>' or '[+!#]setemail ignore' to never be asked again.\n" ..
                          "You can always use '[+!#]setemail <emailaddress>' if you change your mind later."
local msgsv_lastremtosave = "Detta är den sista påminnelsen om att spara din e-postadress.\n" ..
                          "Använd '[+!#]setemail <e-postadress>' eller '[+!#]setemail ignore' för att inte få fler påminnelser.\n" ..
                          "Du kan alltid använda '[+!#]setemail <e-postadress>' om du ångrar dig senare."

local msg_verifyemail = "[ EMAIL ] --> Please verify your email address: "
local msgsv_verifyemail = "[ EMAIL ] --> Verifiera din e-postadress: "

local msg_verifyusage = "Use '[+!#]setemail verify' if this is still your current email address or use the right-click menu."
local msgsv_verifyusage = "Använd '[+!#]setemail verify' om detta fortfarande är din aktuella e-postadress eller använd högerklicksmenyn."

--------------------
-- LOCALS
--------------------

local hub_bot = hub.getbot()
local emails  = {}
local hubcmd

local function is_valid_email(email)
    if not email then return false end
    if #email < 6 or #email > 254 then return false end
    if not utf.match(email, "^[%w%._%+%-]+@[%w%-%.]+%.%a%a+$")
       or utf.match(email, "%.%.")
       or utf.match(email, "^%.")
       or utf.match(email, "%.@")
       or utf.match(email, "@%.")
       or utf.match(email, "%.$")
       or utf.match(email, "@%-")
       or utf.match(email, "%-%.")
       or utf.match(email, "%.%-")
       or utf.match(email, "%-@") then
        return false
    end
    return true
end

local function lang( msg, msgsv )
    if showlang == "en" then
        return "\n" .. msg or ""
    elseif showlang == "sv" then
        return "\n" .. msgsv or ""
    else
        if msg and msgsv then
            return "\n" .. msg .. "\n\n" .. msgsv
        else
            return msg or msgsv or ""
        end
    end
end

local function lang_block( msg, msgsv )
    return msg_header .. lang( msg, msgsv ) .. msg_footer
end

--------------------
-- DATA
--------------------

local function loadtbl()
    local f = loadfile(data_file)
    if f then
        local t = f()
        if type(t) == "table" then
            emails = t
        end
    end
end

local function savetbl()
    local f = io.open(data_file, "w")
    if not f then return end

    f:write("return {\n")
    for cid, v in pairs(emails) do
        f:write(string.format('    ["%s"] = {\n', cid))
        f:write(string.format('        ["email"] = "%s",\n', v.email))
        f:write(string.format('        ["last_reminder"] = %d,\n', v.last_reminder))
        f:write(string.format('        ["saved_nick"] = "%s",\n', v.saved_nick))
        f:write("    },\n")
    end
    f:write("}\n")
    f:close()
end

--------------------
-- COMMAND HANDLER
--------------------

local onbmsg = function(user, cmd, parameters, txt)

    local data = parameters or ""

    local cid   = user:cid()
    local nick  = user:nick()
    local level = user:level()
    local now   = os.time()

    emails[cid] = emails[cid] or {
        email = "",
        last_reminder = 0,
        saved_nick = nick,
    }

    local arg1, arg2 = utf.match(data, "^(%S+)%s*(.*)$")
    arg1 = arg1 or ""
    arg2 = arg2 or ""

    -- permission check for user commands
    if level < minlevel and level < oplevel then
        user:reply( lang( msg_denied, msgsv_denied ), hub_bot )
        return PROCESSED
    end

    --------------------------------------------------
    -- USER COMMANDS
    --------------------------------------------------

    if arg1 == "show" then
        if emails[cid].email == "" then
            user:reply( lang( msg_noemail, msgsv_noemail ), hub_bot )
        else
            user:reply( lang( msg_showemail .. emails[cid].email, msgsv_showemail .. emails[cid].email ), hub_bot )
        end
        return PROCESSED
    end

    if arg1 == "delete" then
    
        -- no email to delete
        if not emails[cid] or emails[cid].email == "" then
            user:reply( lang( msg_noemailtodel, msgsv_noemailtodel ), hub_bot )
            return PROCESSED
        end
    
        -- confirmation missing or wrong
        if utf.lower(arg2 or "") ~= "yes" then
            user:reply( lang( msg_delcancel, msgsv_delcancel ), hub_bot )
            return PROCESSED
        end
    
        -- confirmed deletion
        local deleted_email = emails[cid].email
        emails[cid] = nil
        savetbl()
        user:reply( lang( msg_delsuccess .. deleted_email, msgsv_delsuccess .. deleted_email ), hub_bot )
        return PROCESSED
    end

    if arg1 == "ignore" then
    
        -- second ignore → permanent optout
        if emails[cid].email == "" and emails[cid].last_reminder > 0 then
            emails[cid].email = "optout"
            emails[cid].last_reminder = now
            user:reply( lang( msg_rempermdis, msgsv_rempermdis ), hub_bot )
        else
            -- first ignore
            emails[cid].last_reminder = now
            user:reply( lang( msg_remoncemore, msgsv_remoncemore ), hub_bot )
        end
    
        savetbl()
        return PROCESSED
    end

    if arg1 == "verify" then
        if emails[cid].email == "" then
            user:reply( msg_noemail, hub_bot )
        else
            emails[cid].last_reminder = now
            savetbl()
            user:reply( lang( msg_verified .. emails[cid].email, msgsv_verified .. emails[cid].email ), hub_bot )
        end
        return PROCESSED
    end

    --------------------------------------------------
    -- OP COMMANDS
    --------------------------------------------------

    if level >= oplevel then

        -- show all emails
        if arg1 == "showall" then
            local list = {}
        
            for _, v in pairs(emails) do
                if v.email ~= "" and v.email ~= "optout" then
                    table.insert(list, { nick = v.saved_nick, email = v.email })
                end
            end
        
            table.sort(list, function(a, b)
                return utf.lower(a.nick) < utf.lower(b.nick)
            end)
        
            if #list == 0 then
                user:reply( "[ EMAIL ] --> No email addresses saved.", hub_bot )
                return PROCESSED
            end
        
            for _, v in ipairs(list) do
                user:reply( v.nick .. " : " .. v.email, hub_bot )
            end
        
            return PROCESSED
        end

        -- add <nick> <email> (online users only)
        if arg1 == "add" then
            local target_nick, email = utf.match(arg2, "^(%S+)%s+(%S+)$")

            if not target_nick or not email then
                user:reply( msg_op_usage, hub_bot )
                return PROCESSED
            end

            if not is_valid_email(email) then
                user:reply( lang( msg_invalid, msgsv_invalid ), hub_bot )
                return PROCESSED
            end

            local target_user = nil

            for _, u in pairs(hub.getusers()) do
                if utf.lower(u:nick()) == utf.lower(target_nick) then
                    target_user = u
                    break
                end
            end

            if not target_user then
                user:reply( msg_op_mustonline, hub_bot )
                return PROCESSED
            end

            local tcid  = target_user:cid()
            local tnick = target_user:nick()

            emails[tcid] = emails[tcid] or {
                email = "",
                last_reminder = 0,
                saved_nick = tnick,
            }

            emails[tcid].email = email
            emails[tcid].last_reminder = now
            emails[tcid].saved_nick = tnick

            savetbl()
            user:reply( msg_op_emailfor .. tnick .. msg_op_emailfor2 .. email, hub_bot )

            return PROCESSED
        end

        -- showop <nick>
        if arg1 == "showop" and arg2 ~= "" then
            for _, v in pairs(emails) do
                if utf.lower(v.saved_nick) == utf.lower(arg2) then
                    user:reply( v.saved_nick .. " : " .. v.email, hub_bot )
                    return PROCESSED
                end
            end
            user:reply( msg_op_noemailfor .. arg2, hub_bot )
            return PROCESSED
        end

        -- deleteop
        if arg1 == "deleteop" and arg2 ~= "" then
            for cid2, v in pairs(emails) do
                if utf.lower(v.saved_nick) == utf.lower(arg2) then
                    emails[cid2] = nil
                    savetbl()
                    user:reply( msg_op_emailfor .. arg2 .. msg_op_emaildeleted .. v.email, hub_bot )
                    return PROCESSED
                end
            end
            user:reply( msg_op_noemailfound .. arg2, hub_bot )
            return PROCESSED
        end

        -- verifyop <nick>
        if arg1 == "verifyop" and arg2 ~= "" then
            for _, v in pairs(emails) do
                if utf.lower(v.saved_nick) == utf.lower(arg2) then
                    v.last_reminder = now
                    savetbl()
                    user:reply( msg_op_emailfor .. arg2 .. msg_op_verified .. v.email, hub_bot )
                    return PROCESSED
                end
            end
            user:reply( msg_op_noemailfound .. arg2, hub_bot )
            return PROCESSED
        end

        -- ignoreop <nick>
        if arg1 == "ignoreop" and arg2 ~= "" then
            for _, v in pairs(emails) do
                if utf.lower(v.saved_nick) == utf.lower(arg2) then
                    v.email = "optout"
                    v.last_reminder = now
                    savetbl()
                    user:reply( msg_op_emailfor .. arg2 .. msg_op_ignored, hub_bot )
                    return PROCESSED
                end
            end
            user:reply( msg_op_noemailfound .. arg2, hub_bot )
            return PROCESSED
        end

        -- whois
        if arg1 == "whois" and arg2 ~= "" then
            for _, v in pairs(emails) do
                if utf.lower(v.email) == utf.lower(arg2) then
                    user:reply( msg_op_belongsto .. v.saved_nick, hub_bot )
                    return PROCESSED
                end
            end
            user:reply( msg_op_nouserfound .. arg2, hub_bot )
            return PROCESSED
        end
    end

    --------------------------------------------------
    -- SET EMAIL
    --------------------------------------------------

    if data ~= "" then
        if not is_valid_email(data) then
            user:reply( lang( msg_invalid, msgsv_invalid ), hub_bot )
            return PROCESSED
        end

        emails[cid].email = data
        emails[cid].last_reminder = now
        emails[cid].saved_nick = nick
        savetbl()
        user:reply( lang( msg_emailsaved .. emails[cid].email, msgsv_emailsaved .. emails[cid].email ), hub_bot )
        return PROCESSED
    end

    --------------------------------------------------
    -- HELP
    --------------------------------------------------

    if level < oplevel then
        user:reply( help_usage, hub_bot )
    end
    
    if level >= oplevel then
        user:reply( help_op_usage, hub_bot )
    end
    
    return PROCESSED
end

--------------------
-- LOGIN REMINDER
--------------------

hub.setlistener("onLogin", {},
    function(user)

        if ask_level[user:level()] ~= 1 then
            return nil
        end

        local cid = user:cid()
        local e = emails[cid]
        local now = os.time()

        -- update saved nick only if email exists
        if e and e.email ~= "" and e.email ~= "optout" then
            if e.saved_nick ~= user:nick() then
                e.saved_nick = user:nick()
                savetbl()
            end
        end

        -- user changed CID but kept same nick
        if not e then
            for oldcid, v in pairs(emails) do
                if utf.lower(v.saved_nick) == utf.lower(user:nick()) then
                    emails[cid] = v
                    emails[oldcid] = nil
                    savetbl()

                    e = emails[cid]
                    break
                end
            end
        end

        -- update nick if it has changed
        if e and e.saved_nick ~= user:nick() then
            e.saved_nick = user:nick()
            savetbl()
        end

        -- user has no entry yet
        if not e then
            user:reply( lang_block( msg_noentry, msgsv_noentry ), hub_bot )
            return nil
        end

        -- user opted out
        if e.email == "optout" then
            return nil
        end

        --------------------------------------------------
        -- NO EMAIL SAVED → use reminder_minutes
        --------------------------------------------------
        if e.email == "" then
            if now - (e.last_reminder or 0) >= reminder_minutes * 60 then
                user:reply( lang( msg_lastremtosave, msgsv_lastremtosave ), hub_bot )
                e.last_reminder = now
                savetbl()
            end
            return nil
        end

        --------------------------------------------------
        -- EMAIL SAVED → use verify_reminder
        --------------------------------------------------
        if now - e.last_reminder >= verify_reminder * 60 then
            user:reply( lang( msg_verifyemail .. e.email .. "\n" .. msg_verifyusage, msgsv_verifyemail .. e.email .. "\n" .. msgsv_verifyusage ), hub_bot )
        end
        return nil
    end
)

--------------------
-- STARTUP
--------------------

hub.setlistener("onStart", {}, function()
    
    hubcmd = hub.import("etc_hubcommands")
    assert(hubcmd)
    assert(hubcmd.add("setemail", onbmsg))

     --// help, ucmd
     local help = hub.import( "cmd_help" )
     if help then
         help.reg( help_title, help_usage, help_desc, minlevel )
         help.reg( help_op_title, help_op_usage, help_op_desc, oplevel )
     end

    local ucmd = hub.import "etc_usercommands"
    if not ucmd then return nil end

    local cmd = "setemail"

    --------------------------------------------------
    -- USER MENU (visible to everyone, including OPs)
    --------------------------------------------------

    ucmd.add( { "Email", "Add email" }, cmd, { "%[line:Enter your email address]" }, { "CT1" }, minlevel )

    ucmd.add( { "Email", "Show email" }, cmd, { "show" }, { "CT1" }, minlevel )

    ucmd.add( { "Email", "Verify email" }, cmd, { "verify" }, { "CT1" }, minlevel )

    ucmd.add( { "Email", "Delete email" }, cmd, { "delete", "%[line:Type 'YES' if you want to delete your email address]" }, { "CT1" }, minlevel )

    ucmd.add( { "Email", "Ignore reminder" }, cmd, { "ignore" }, { "CT1" }, minlevel )

    --------------------------------------------------
    -- OP MENU (MAIN CHAT)
    --------------------------------------------------

    ucmd.add( { "Email", "OP", "Show user email" }, cmd, { "showop", "%[line:Username:]" }, { "CT1" }, oplevel )

    ucmd.add( { "Email", "OP", "Delete user email" }, cmd, { "deleteop", "%[line:Username:]" }, { "CT1" }, oplevel )

    ucmd.add( { "Email", "OP", "Verify user email" }, cmd, { "verifyop", "%[line:Username:]" }, { "CT1" }, oplevel )

    ucmd.add( { "Email", "OP", "Ignore user email" }, cmd, { "ignoreop", "%[line:Username:]" }, { "CT1" }, oplevel )

    ucmd.add( { "Email", "OP", "Whois email" }, cmd, { "whois", "%[line:Email address:]" }, { "CT1" }, oplevel )

    ucmd.add( { "Email", "OP", "Show all emails" }, cmd, { "showall" }, { "CT1" }, oplevel )

    --------------------------------------------------
    -- OP MENU (USER LIST)
    --------------------------------------------------

    ucmd.add( { "Email", "Add email (online user)" }, cmd, { "add", "%[userNI]", "%[line:Email address]" }, { "CT2" }, oplevel )

    ucmd.add( { "Email", "Show user email" }, cmd, { "showop", "%[userNI]" }, { "CT2" }, oplevel )

    ucmd.add( { "Email", "Delete user email" }, cmd, { "deleteop", "%[userNI]" }, { "CT2" }, oplevel )

    ucmd.add( { "Email", "Verify user email" }, cmd, { "verifyop", "%[userNI]" }, { "CT2" }, oplevel )

    ucmd.add( { "Email", "Ignore user email" }, cmd, { "ignoreop", "%[userNI]" }, { "CT2" }, oplevel )

    return nil
end
)

loadtbl()
hub.debug( "** Loaded "..scriptname.."_"..scriptversion..".lua **" )
