#!/bin/sh

set -e

ZOIDBERG_LISTEN=${ZOIDBERG_LISTEN:-127.0.0.1:13000}

sed -i "s/%zoidberg_listen%/${ZOIDBERG_LISTEN}/g" /etc/nginx/nginx.conf

mkdir -p /etc/nginx/zoidberg/apps
chown nginx:nginx /etc/nginx/zoidberg/apps

exec nginx "$@"
