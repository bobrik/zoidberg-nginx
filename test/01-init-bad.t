use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (4 + 4);

run_tests();

__DATA__
=== TEST 1: Init with missing apps
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location /test {
        content_by_lua_block {
            require("zoidberg").init("missing_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            ngx.say("OK")
        }
    }
--- request
GET /test
--- response_body
OK
--- error_log
apps dictionary missing_apps not found
--- no_error_log
restoring app state from file


=== TEST 2: Init with missing locks
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location /test {
        content_by_lua_block {
            require("zoidberg").init("zoidberg_apps", "missing_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            ngx.say("OK")
        }
    }
--- request
GET /test
--- response_body
OK
--- error_log
locks dictionary missing_locks not found
--- no_error_log
restoring app state from file
