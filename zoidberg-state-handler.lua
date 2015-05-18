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
    local enabled = {}

    for name, app in pairs(state.apps) do
        local servers = ""

        for i, server in ipairs(app.servers) do
            if state.versions[name] then
                if state.versions[name][server.version].weight > 0 then
                    servers = servers .. "server " .. server.host .. ":" .. server.port .. " weight=" .. state.versions[name][server.version].weight .. ";"
                end
            end
        end

        if string.len(servers) > 0 then
            ngx.log(ngx.NOTICE, name .. " -> " .. servers)
            local status, rv = require("ngx.dyups").update(name, servers)
            ngx.log(ngx.NOTICE, status .. " -> " .. rv)

            enabled[name] = true
        end
    end

    ngx.shared.zoidberg_state = { state = state, enabled = enabled }

    return ngx.exit(204)
else
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
end
