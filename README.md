# nginx managed by Zoidberg

This is a POC of a service discovery mechanism made of nginx server
managed by [zoidberg](https://github.com/bobrik/zoidberg). The main
use-case is to provide service discovery for mesos.

The main goal of this project is to provide service discovery capable
of doing frequent state updates (at least 1 per second) without spawning
any additional processes. Most of haproxy and nginx based service discovery
mechanisms reload server causing explosion in number of processes.
This is not acceptable in the environments where you have long-lived
connections and frequent updates of backend servers.

Another goal is to reuse rich ecosystem of nginx modules and lua scripting.

## Usage

Create simple config for your application `myapp.zoidberg`:

`/tmp/myapp.conf`:

```
server {
    listen lb1.prod:13003;

    location / {
        set $where myapp.zoidberg;
        proxy_pass http://$where;
    }
}
```

Then run `zoidberg-nginx` with provided config:

```
docker run -d --net host -e ZOIDBERG_LISTEN=lb1.prod:13000 \
    -v /tmp/myapp.conf:/etc/nginx/include/http/myapp.conf:ro \
    --name zoidberg-nginx bobrik/zoidberg-nginx
```

Add some servers to your load balancer:

`state.json`:

```json
{
    "apps": {
        "myapp.zoidberg": {
            "name": "myapp.zoidberg",
            "port": 13003,
            "servers": [
                {
                    "host": "example.com",
                    "port": 80,
                    "version": "/v1"
                }
            ]
        }
    },
    "state": {
        "versions": {
            "myapp.zoidberg": {
                "/v1": {
                    "name": "/v1",
                    "weight": 1
                }
            }
        }
    }
}
```

```
curl -v -X POST http://lb1.prod:13000/state -d @state.json
```

Feel free to change state to whatever you think is appropriate. In fact,
Zoidberg should update state in real world, not a silly human like you.


To check if your balancer works:

```
curl -v http://lb1.prod:13003/
```

You should see the contents of `example.com` in your terminal.
