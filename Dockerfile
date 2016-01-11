FROM bobrik/openresty

ENTRYPOINT ["/run.sh"]

COPY ./run.sh /run.sh

COPY ./etc-nginx /etc/nginx
