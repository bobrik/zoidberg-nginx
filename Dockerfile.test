FROM bobrik/openresty

RUN apt-get update && \
    apt-get install -y --no-install-recommends git perl libtest-base-perl libtest-longstring-perl liblist-moreutils-perl libwww-perl

RUN git clone https://github.com/openresty/test-nginx.git /tmp/test-nginx && \
    cd /tmp/test-nginx && \
    git checkout ae6e75c391eafe680cc991d09cbe53e3d1f5d729

COPY ./etc-nginx /etc/nginx
COPY ./test /tmp/zoidberg-nginx-test

RUN cd /tmp && \
    mkdir -p t/servroot && \
    TEST_NGINX_NO_SHUFFLE=1 TEST_NGINX_SERVER_PORT=1984 prove -I/tmp/test-nginx/lib -r /tmp/zoidberg-nginx-test
