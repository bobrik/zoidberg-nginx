use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (5);

run_tests();

__DATA__
=== TEST 1: Balance with valid app
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
    location = /ok.txt {
      rewrite_by_lua_block {
          local zoidberg = require("zoidberg")

          local manager, err = zoidberg:new("zoidberg_apps", "zoidberg_locks", "/tmp/zoidberg-nginx-test/init-dumps/empty", {"8.8.8.8"})
          if err then
            ngx.log(ngx.ERR, err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
          end

          local err = manager:updateApp("mygroup", "local.app", {
            servers = {
              {
                host   = "127.0.0.1",
                port   = 1984,
                weight = 1,
              },
            }
          })
          if err then
            ngx.log(ngx.ERR, err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
          end

          ngx.req.set_uri("/real-ok.txt")
      }

      set $zoidberg_app local.app;
      proxy_set_header Host bobrik.name;
      proxy_pass http://zoidberg-managed;
    }

    location = /real-ok.txt {
        echo "OK";
    }
--- request
GET /ok.txt
--- response_body
OK
--- no_error_log
[error]
[warn]
restoring app state from file
