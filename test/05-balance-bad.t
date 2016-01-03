use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (4 + 4);

run_tests();

__DATA__
=== TEST 1: Balance without setting app
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;

    upstream zoidberg-managed {
        server 127.0.0.1:1;
        balancer_by_lua_block {
            require("zoidberg").balance("zoidberg_apps", "zoidberg_locks")
        }
    }

    init_by_lua_block {
        io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()
        require("zoidberg").init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
    }
--- config
    location = /balance {
        proxy_pass http://zoidberg-managed;
    }
--- request
GET /balance
--- error_code: 502
--- error_log
$zoidberg_app is not specified while connecting to upstream
--- no_error_log
[warn]
restoring app state from file


=== TEST 2: Balance with unknown app
--- http_config
    lua_package_path "/etc/nginx/lualib/?.lua;/etc/nginx/lua/?.lua;";

    lua_shared_dict zoidberg_apps  5m;
    lua_shared_dict zoidberg_locks 1m;

    upstream zoidberg-managed {
        server 127.0.0.1:1;
        balancer_by_lua_block {
            require("zoidberg").balance("zoidberg_apps", "zoidberg_locks")
        }
    }

    init_by_lua_block {
        io.popen("cd /tmp/zoidberg-nginx-test/init-dumps/empty && ls | xargs --no-run-if-empty rm"):close()
        require("zoidberg").init("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty")
    }
--- config
    location = /balance {
        set $zoidberg_app totally-missing@app;
        proxy_pass http://zoidberg-managed;
    }
--- request
GET /balance
--- error_code: 502
--- error_log
app totally-missing@app is not know or has no known instances while connecting to upstream
--- no_error_log
[warn]
restoring app state from file
