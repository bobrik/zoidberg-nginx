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

Don't go YOLO and run in in production yet, okay?

Launch load balancer somewhere, exposing managing and service discovery ports:

```
docker run -d \
    -p <service discovery host>:<service discovery port>:80 \
    -p <managment host>:<management port>:9000 \
    --name zoidberg-nginx bobrik/zoidberg-nginx
```

Add some servers to your load balancer:

`state.json`:

```json
{
    "apps": {
        "myapp": {
            "name": "myapp",
            "port": 1313,
            "servers": [
                {
                    "host": "example.com",
                    "port": 80,
                    "version": "/v1"
                }
            ]
        }
    },
    "versions": {
        "myapp": {
            "/v1": {
                "name": "/v1",
                "weight": 1
            }
        }
    }
}
```

```
curl -v -X POST http://<managment host>:<management port>/state -d @state.json
```

Feel free to change state to whatever you think is appropriate. In fact,
Zoidberg should update state in real world, not a silly human like you.


To check if your balancer works:

```
curl -H "Host: myapp" -v http://<service discovery host>:<service discovery port>/
```

You should see the contents of `example.com` in your terminal.
