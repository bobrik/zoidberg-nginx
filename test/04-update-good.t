use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (5 + 5 + 5 + 5);

run_tests();

__DATA__
=== TEST 1: Update with single app with no specific versions
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location ~ ^/state/(?<zoidberg_group>.*)$ {
        content_by_lua_block {
            io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()

            local zoidberg = require("zoidberg")
            local json     = require("cjson")

            zoidberg.init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            zoidberg.handle("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty", {"8.8.8.8"})

            local manager, err = zoidberg:new("zoidberg_apps", "zoidberg_locks")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local state, err = manager:getApp("myapp.zoidberg")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local dump, err = json.encode(state)
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.group ~= "mygroup" then
              ngx.log(ngx.ERR, "group is invalid (" .. state.group .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.name ~= "myapp.zoidberg" then
              ngx.log(ngx.ERR, "name is invalid (" .. state.name .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not state.version then
              ngx.log(ngx.ERR, "version is missing: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not (state.app.servers and table.getn(state.app.servers) == 2) then
              ngx.log(ngx.ERR, "servers are missing or incomplete: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the first server is invalid (expected example.com): " .. state.app.servers[1].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].port ~= 10001 then
              ngx.log(ngx.ERR, "port of the first server is invalid (expected 10001): " .. state.app.servers[1].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].weight ~= 1 then
              ngx.log(ngx.ERR, "weight of the first server is invalid (expected 1): " .. state.app.servers[1].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the first server is invalid (expected 93.184.216.34): " .. state.app.servers[1].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the second server is invalid (expected example.com): " .. state.app.servers[2].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].port ~= 10002 then
              ngx.log(ngx.ERR, "port of the second server is invalid (expected 10002): " .. state.app.servers[2].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].weight ~= 1 then
              ngx.log(ngx.ERR, "weight of the second server is invalid (expected 1): " .. state.app.servers[2].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the second server is invalid (expected 93.184.216.34): " .. state.app.servers[2].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            ngx.say("OK")
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [
                {
                    "host": "example.com",
                    "port": 10001,
                    "version": "1"
                },
                {
                    "host": "example.com",
                    "port": 10002,
                    "version": "1"
                }
            ]
        }
    },
    "state": {
      "versions": {}
    }
}
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file


=== TEST 2: Update with single app with two versions and weight
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location ~ ^/state/(?<zoidberg_group>.*)$ {
        content_by_lua_block {
            io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()

            local zoidberg = require("zoidberg")
            local json     = require("cjson")

            zoidberg.init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            zoidberg.handle("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty", {"8.8.8.8"})

            local manager, err = zoidberg:new("zoidberg_apps", "zoidberg_locks")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local state, err = manager:getApp("myapp.zoidberg")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local dump, err = json.encode(state)
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.group ~= "mygroup" then
              ngx.log(ngx.ERR, "group is invalid (" .. state.group .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.name ~= "myapp.zoidberg" then
              ngx.log(ngx.ERR, "name is invalid (" .. state.name .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not state.version then
              ngx.log(ngx.ERR, "version is missing: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not (state.app.servers and table.getn(state.app.servers) == 2) then
              ngx.log(ngx.ERR, "servers are missing or incomplete: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the first server is invalid (expected example.com): " .. state.app.servers[1].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].port ~= 20001 then
              ngx.log(ngx.ERR, "port of the first server is invalid (expected 20001): " .. state.app.servers[1].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].weight ~= 1 then
              ngx.log(ngx.ERR, "weight of the first server is invalid (expected 1): " .. state.app.servers[1].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the first server is invalid (expected 93.184.216.34): " .. state.app.servers[1].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the second server is invalid (expected example.com): " .. state.app.servers[2].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].port ~= 20002 then
              ngx.log(ngx.ERR, "port of the second server is invalid (expected 20002): " .. state.app.servers[2].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].weight ~= 8 then
              ngx.log(ngx.ERR, "weight of the second server is invalid (expected 8): " .. state.app.servers[2].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the second server is invalid (expected 93.184.216.34): " .. state.app.servers[2].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            ngx.say("OK")
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [
                {
                    "host": "example.com",
                    "port": 20001,
                    "version": "1"
                },
                {
                    "host": "example.com",
                    "port": 20002,
                    "version": "2"
                }
            ]
        }
    },
    "state": {
        "versions": {
            "myapp.zoidberg": {
                "1": {
                    "weight": 1
                },
                "2": {
                    "weight": 8
                }
            }
        }
    }
}
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file


=== TEST 3: Update with single app with a specific version in one upstream
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location ~ ^/state/(?<zoidberg_group>.*)$ {
        content_by_lua_block {
            io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()

            local zoidberg = require("zoidberg")
            local json     = require("cjson")

            zoidberg.init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            zoidberg.handle("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty", {"8.8.8.8"})

            local manager, err = zoidberg:new("zoidberg_apps", "zoidberg_locks")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local state, err = manager:getApp("myapp.zoidberg")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local dump, err = json.encode(state)
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.group ~= "mygroup" then
              ngx.log(ngx.ERR, "group is invalid (" .. state.group .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.name ~= "myapp.zoidberg" then
              ngx.log(ngx.ERR, "name is invalid (" .. state.name .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not state.version then
              ngx.log(ngx.ERR, "version is missing: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not (state.app.servers and table.getn(state.app.servers) == 1) then
              ngx.log(ngx.ERR, "servers are missing or incomplete: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the first server is invalid (expected example.com): " .. state.app.servers[1].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].port ~= 30002 then
              ngx.log(ngx.ERR, "port of the first server is invalid (expected 30002): " .. state.app.servers[1].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].weight ~= 3 then
              ngx.log(ngx.ERR, "weight of the first server is invalid (expected 3): " .. state.app.servers[1].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the first server is invalid (expected 93.184.216.34): " .. state.app.servers[1].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            ngx.say("OK")
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [
                {
                    "host": "example.com",
                    "port": 30001,
                    "version": "1"
                },
                {
                    "host": "example.com",
                    "port": 30002,
                    "version": "2"
                }
            ]
        }
    },
    "state": {
        "versions": {
            "myapp.zoidberg": {
                "2": {
                    "weight": 3
                }
            }
        }
    }
}
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file


=== TEST 4: Update with single app with ip in host field
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location ~ ^/state/(?<zoidberg_group>.*)$ {
        content_by_lua_block {
            io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()

            local zoidberg = require("zoidberg")
            local json     = require("cjson")

            zoidberg.init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            zoidberg.handle("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty", {"8.8.8.8"})

            local manager, err = zoidberg:new("zoidberg_apps", "zoidberg_locks")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local state, err = manager:getApp("myapp.zoidberg")
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            local dump, err = json.encode(state)
            if err then
              ngx.log(ngx.ERR, err)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.group ~= "mygroup" then
              ngx.log(ngx.ERR, "group is invalid (" .. state.group .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.name ~= "myapp.zoidberg" then
              ngx.log(ngx.ERR, "name is invalid (" .. state.name .. "): " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not state.version then
              ngx.log(ngx.ERR, "version is missing: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if not (state.app.servers and table.getn(state.app.servers) == 2) then
              ngx.log(ngx.ERR, "servers are missing or incomplete: " .. dump)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].host ~= "example.com" then
              ngx.log(ngx.ERR, "host of the first server is invalid (expected example.com): " .. state.app.servers[1].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].port ~= 40001 then
              ngx.log(ngx.ERR, "port of the first server is invalid (expected 40001): " .. state.app.servers[1].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].weight ~= 1 then
              ngx.log(ngx.ERR, "weight of the first server is invalid (expected 1): " .. state.app.servers[1].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[1].addr ~= "93.184.216.34" then
              ngx.log(ngx.ERR, "addr of the first server is invalid (expected 93.184.216.34): " .. state.app.servers[1].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].host ~= "1.2.3.5" then
              ngx.log(ngx.ERR, "host of the second server is invalid (expected 1.2.3.5): " .. state.app.servers[2].host)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].port ~= 40002 then
              ngx.log(ngx.ERR, "port of the second server is invalid (expected 40002): " .. state.app.servers[2].port)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].weight ~= 1 then
              ngx.log(ngx.ERR, "weight of the second server is invalid (expected 1): " .. state.app.servers[2].weight)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            if state.app.servers[2].addr ~= "1.2.3.5" then
              ngx.log(ngx.ERR, "addr of the second server is invalid (expected 1.2.3.5): " .. state.app.servers[2].addr)
              ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end

            ngx.say("OK")
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [
                {
                    "host": "example.com",
                    "port": 40001,
                    "version": "1"
                },
                {
                    "host": "1.2.3.5",
                    "port": 40002,
                    "version": "1"
                }
            ]
        }
    },
    "state": {
        "versions": {}
    }
}
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file
