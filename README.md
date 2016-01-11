# Nginx managed by Zoidberg

This is nginx-based load balancer implementation managed by
[zoidberg](https://github.com/bobrik/zoidberg). The main use-case of this
project is to provide service discovery for Mesos.

The main goal of this project is to provide service discovery capable
of doing frequent state updates (at least 1 per second) without spawning
any additional processes. Most of haproxy and nginx based service discovery
mechanisms reload server causing explosion in number of processes.
This is not acceptable in the environments where you have long-lived
connections and frequent updates of backend servers.

Another goal is to reuse rich ecosystem of nginx modules and lua scripting.

This projects depends on `balancer_by_lua_block` provided by OpenResty.

## Usage

Create simple config for your application `myapp.zoidberg`:

`/tmp/myapp.conf`:

```
server {
    listen 8888;

    location / {
        set $zoidberg_app myapp.zoidberg;
        proxy_pass http://zoidberg-managed;
        proxy_set_header Host example.com;
    }
}
```

Then run `zoidberg-nginx` with provided config:

```
docker run --rm -it --net host -e ZOIDBERG_LISTEN=13000 \
    -v /tmp/myapp.conf:/etc/nginx/include/http/myapp.conf:ro \
    --name zoidberg-nginx bobrik/zoidberg-nginx
```

Add some servers to your load balancer:

`state.json`:

```json
{
    "apps": {
        "myapp.zoidberg": {
            "servers": [
                {
                    "host": "example.com",
                    "port": 80,
                    "version": "1"
                }
            ]
        }
    },
    "state": {
        "versions": {
            "myapp.zoidberg": {
                "1": {
                    "weight": 1
                }
            }
        }
    }
}
```

```
curl -v -X POST http://mybalancer:13000/state/mygroup -d @state.json
```

Feel free to change state to whatever you think is appropriate. In fact,
Zoidberg should update state in real world, not a silly human like you.

Here `mygroup` is the name of your group. Groups are managed by different
Zoidberg instances that can use different discovery mechanisms or even
different Mesos clusters.

To check if your balancer works:

```
curl -v http://mybalancer:8888/
```

You should see the contents of `example.com` in your terminal.

### Default version

Version `1` is automatically enabled with `weight` set to `1`. This allows
you to skip version setting in the deployment process.

## External usage

Module `zoidberg.lua` depends on OpenResty, so you can use it outside of
the provided docker image. Take a look at [nginx.conf](./etc-nginx/nginx.conf)
to see how things work and what you can change.

## Performance

The following test using [wrk](https://github.com/wg/wrk), best of 3 runs:

```
wrk -t2 -c50 -d30s
```

Upstream server does the following:

```
location /{
    echo OK;
}
```

* `106317.43 req/s`

Basic proxy doing the following:

```
location / {
    proxy_pass http://upstream;
}
```

* `47560.04 req/s`

Zoidberg nginx doing the following:

```
location /zoidberg {
    set $zoidberg_app upstream;
    proxy_pass http://zoidberg-managed;
}
```

* `34906.87 req/s`

Clearly, there is a room for improvement here.

## Running tests

```
docker build -f Dockerfile.test .
```
