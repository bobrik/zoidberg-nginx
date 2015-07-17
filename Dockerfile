FROM debian:jessie

RUN echo "APT::Install-Recommends false;" >> /etc/apt/apt.conf.d/recommends.conf && \
    echo "APT::AutoRemove::RecommendsImportant false;" >> /etc/apt/apt.conf.d/recommends.conf && \
    echo "APT::AutoRemove::SuggestsImportant false;" >> /etc/apt/apt.conf.d/recommends.conf && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y build-essential curl libpcre3-dev zlib1g-dev git && \
    apt-get install -y ca-certificates luajit-5.1-dev lua-cjson && \
    mkdir /workdir && \
    curl -s http://nginx.org/download/nginx-1.9.3.tar.gz | tar zx -C /workdir && \
    git clone https://github.com/yzprofile/ngx_http_dyups_module.git /workdir/ngx_http_dyups_module && \
    git clone https://github.com/chaoslawful/lua-nginx-module.git /workdir/lua-nginx-module && \
    useradd --no-create-home nginx && \
    cd /workdir/nginx-1.9.3 && \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --group=nginx \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --add-module=/workdir/lua-nginx-module \
        --add-module=/workdir/ngx_http_dyups_module && \
    make && \
    make install && \
    apt-get remove -y build-essential curl libpcre3-dev zlib1g-dev git && \
    apt-get autoremove -y

VOLUME ["/etc/nginx/include/http"]
ENTRYPOINT ["/run.sh"]

COPY ./run.sh /run.sh
COPY ./include /etc/nginx/include
COPY ./lua /etc/nginx/lua
COPY ./nginx.conf /etc/nginx/nginx.conf

RUN chown -R nginx /etc/nginx/include/dyups
