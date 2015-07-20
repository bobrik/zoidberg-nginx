--                             __....-------....__
--                       ..--'"                   "`-..
--                    .'"                              `.
--                  :'                                   `,
--                .'                                       ".
--               :                                           :
--              :                                             b
--             d                                              `b
--             :                                               :
--             :                                               b
--            :                                                q
--            :                                                `:
--           :                                                  :
--          ,'                                                  :
--         :    _____                  _____                   p'
--         \,.-'     `-.            .-'     `-.                :
--         .'           `.        .'           `.              :
--        /               \      /               \            p'
--       :      @          ;    :      @          ;           :
--       \                 \    \                 \           :
--       :                 ;    :                 ;          ,:
--        \               /      \               /           p
--        /`.           .'        `.           .'           :
--       q_  `-._____.-.            `-._____.-'             :
--        /"-__     .""           "-.__                    :'
--       (_    ""-.'                   """---bmw           :
--         "._.-""                                        ,:
--        ,""                                             P
--      ."                                                :
--     "      _."      ."        ."        _...           :
--    P     ."        "        .'        ,"####)          :
--   :     ."       ."        /        ,'######'          :
--   :     :       (        ,"        ,########:         ,:
--    q    `.      '.       ,        :######,-'          :
--    `:    b       q       :        '--''""             :
--     :     :      :       :        :                   :
--     :     :      `:      `.       ".                 :'
--     q_    :       :       :         )                :
--       ""'b`._   ,.`.____,' `._   _.'                 ,
--          \.__"""              """     _______.......',
--        ,'    """""""-----.------"""""""               :
--        :                 :                            :
--        :                 :                            :
--        :.__              :           ________.......,'
--            """"""""------'------""""""

local cjson = require("cjson")
local group = ngx.var.zoidberg_group
local state_key = "state:" .. group

if ngx.req.get_method() == "GET" then
    ngx.header.content_type = "application/json";

    local state = ngx.shared.zoidberg:get(state_key)
    if not state then
        return ngx.say("{}")
    end

    return ngx.say(cjson.new().encode(cjson.decode(state).state))
elseif ngx.req.get_method() == "PUT" or ngx.req.get_method() == "POST" then
    ngx.req.read_body()

    local state = cjson.new().decode(ngx.req.get_body_data())
    local zoidberg = ngx.shared.zoidberg
    local global_directives = zoidberg:get("global_directives")
    local enabled = {}
    local saved = {}

    local current = {}
    local current_serialized = zoidberg:get(state_key)
    if current_serialized then
        current = cjson.new().decode(current_serialized)
    end

    for name, app in pairs(state.apps) do
        local directives = {}

        for _, server in ipairs(app.servers) do
            if state.state.versions[name] then
                if state.state.versions[name][server.version] then
                    if state.state.versions[name][server.version].weight > 0 then
                        local host = server.host
                        local port = server.port
                        local weight = state.state.versions[name][server.version].weight
                        table.insert(directives, "server " .. host .. ":" .. port .. " weight=" .. weight .. ";")
                    end
                elseif server.version == "1" then
                    table.insert(directives, "server " .. server.host .. ":" .. server.port .. " weight=1;")
                end
            end
        end

        local servers = table.getn(directives)

        table.sort(directives)

        if global_directives then
            table.insert(directives, global_directives)
        end

        local upstream_directives = zoidberg:get("upstream_directives:" .. name)
        if upstream_directives then
            table.insert(directives, upstream_directives)
        end

        local upstream = table.concat(directives, "\n")

        if table.getn(directives) > 0 then
            if (not current) or (not current.saved) or (not current.saved[name]) or current.saved[name] ~= upstream then
                ngx.log(ngx.NOTICE, "updating " .. name .. ": " .. servers .. " upstreams")
                local status, rv = require("ngx.dyups").update(name, upstream)
                ngx.log(ngx.NOTICE, "updated " .. name .. ": " .. status .. ", " .. rv)
            end

            saved[name] = upstream
            enabled[name] = true
        end
    end

    zoidberg:set(state_key, cjson.new().encode({ state = state, saved = saved, enabled = enabled }))

    local temp_upstreams_file = "/etc/nginx/include/dyups/" .. group .. ".conf.temp"
    local final_upstreams_file = "/etc/nginx/include/dyups/" .. group .. ".conf"
    local dumped, openError = io.open(temp_upstreams_file, "w")
    if not dumped then
        ngx.log(ngx.ERR, "failed to open temp file for upstreams: " .. openError)
    else
        for name, directives in pairs(saved) do
            dumped:write("upstream " .. name .. " {\n")
            dumped:write("    " .. directives:gsub("\n", "\n    ") .. "\n")
            dumped:write("}\n")
        end

        io.close(dumped)

        local moved, moveError = os.rename(temp_upstreams_file, final_upstreams_file)
        if not moved then
            ngx.log(ngx.ERR, "failed to move temp file for upstreams to the place: " .. moveError)
        end
    end

    return ngx.exit(204)
else
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end
