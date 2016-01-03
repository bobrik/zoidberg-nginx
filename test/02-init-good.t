use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (5 + 5 + 7);

run_tests();

__DATA__
=== TEST 1: Init with empty apps
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location /test {
        content_by_lua_block {
            io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()

            require("zoidberg").init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
            ngx.say("OK")
        }
    }
--- request
GET /test
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file


=== TEST 2: Init with single app
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location /test {
        content_by_lua_block {
            require("zoidberg").init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/single")
            ngx.say("OK")
        }
    }
--- request
GET /test
--- response_body
OK
--- error_log: restoring app state from file myapp.json
--- no_error_log
[error]
[warn]

=== TEST 3: Init with multiple apps
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;
--- config
    location /test {
        content_by_lua_block {
            require("zoidberg").init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/many")
            ngx.say("OK")
        }
    }
--- request
GET /test
--- response_body
OK
--- error_log
restoring app state from file one.json
restoring app state from file two.json
restoring app state from file three.json
--- no_error_log
[error]
[warn]
