--[[

    etc_botclients.lua by ShareFixxers

        - shows users with a specific client (e.g. Herald announcers) as bot in the userlist
        - the hub sets the client type CT to "5" (bot + operator) after login
        - match is done on the client name in the INF (VE), case insensitive, from the start

        v0.1:
            - first version

]]--


--// settings begin //--

local botclients = {  -- client names that should be shown as bot

    "Herald",

}

--// settings end //--

local scriptname = "etc_botclients"
local scriptversion = "0.1"

local isbotclient = function( user )
    if user:isbot( ) then return false end
    local ve = user:version( ) or ""  -- AP + VE, e.g. "Herald 1.0.0"
    ve = string.lower( hub.escapefrom( ve ) )
    for _, name in ipairs( botclients ) do
        if string.sub( ve, 1, #name ) == string.lower( name ) then
            return true
        end
    end
    return false
end

local makebot = function( user )
    if isbotclient( user ) then
        user:inf( ):setnp( "CT", "5" )
        hub.sendtoall( "BINF " .. user:sid( ) .. " CT5\n" )
    end
end

hub.setlistener( "onStart", { },
    function( )
        for sid, user in pairs( hub.getusers( ) ) do
            makebot( user )
        end
        return nil
    end
)

hub.setlistener( "onLogin", { },
    function( user )
        makebot( user )
        return nil
    end
)

hub.debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )
