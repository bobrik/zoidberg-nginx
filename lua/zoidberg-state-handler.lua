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

if ngx.req.get_method() == "GET" then
    ngx.header.content_type = "application/json";

    if not ngx.shared.zoidberg_state then
        return ngx.say("{}")
    end

    return ngx.say(require("cjson").new().encode(ngx.shared.zoidberg_state.state))
elseif ngx.req.get_method() == "PUT" or ngx.req.get_method() == "POST" then
    ngx.req.read_body()

    local state = require("cjson").new().decode(ngx.req.get_body_data())
    local current = ngx.shared.zoidberg_state
    local enabled = {}
    local saved = {}

    for name, app in pairs(state.apps) do
        local directives = {}

        for _, server in ipairs(app.servers) do
            if state.state.versions[name] then
                if state.state.versions[name][server.version].weight > 0 then
                    table.insert(directives, "server " .. server.host .. ":" .. server.port .. " weight=" .. state.state.versions[name][server.version].weight .. ";")
                end
            end
        end

        local servers = table.getn(directives)

        table.sort(directives)

        table.insert(directives, "keepalive 32;")

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

    ngx.shared.zoidberg_state = { state = state, saved = saved, enabled = enabled }

    local dumped, openError = io.open("/etc/nginx/include/dyups/upstreams.conf.temp", "w")
    if not dumped then
        ngx.log(ngx.ERR, "failed to open temp file for upstreams: " .. openError)
    else
        for name, directives in pairs(saved) do
            dumped:write("upstream " .. name .. " {\n")
            dumped:write("    " .. directives:gsub("\n", "\n    ") .. "\n")
            dumped:write("}\n")
        end

        io.close(dumped)

        local moved, moveError = os.rename("/etc/nginx/include/dyups/upstreams.conf.temp", "/etc/nginx/include/dyups/upstreams.conf")
        if not moved then
            ngx.log(ngx.ERR, "failed to move temp file for upstreams to the place: " .. moveError)
        end
    end

    return ngx.exit(204)
else
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end
