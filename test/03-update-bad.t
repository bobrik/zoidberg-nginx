use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (6 + 5);

run_tests();

__DATA__
=== TEST 1: Update with no servers
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

            ngx.say("OK")
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": []
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
updated myapp.zoidberg


=== TEST 2: Update with invalid server
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
        }
    }
--- request
POST /state/mygroup
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [{
                "host": "this.is.so.much.not.existing.bobrik.name",
                "port": 20001,
                "version": "1"
            }]
        }
    },
    "state": {
      "versions": {}
    }
}
--- error_code: 500
--- error_log
dns query for this.is.so.much.not.existing.bobrik.name retured zero results
--- no_error_log
[warn]
restoring app state from file
updated myapp.zoidberg
