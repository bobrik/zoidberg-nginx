#!/bin/sh

set -e

ZOIDBERG_LISTEN=${ZOIDBERG_LISTEN:-127.0.0.1:13000}

sed -i "s/%zoidberg_listen%/${ZOIDBERG_LISTEN}/g" /etc/nginx/nginx.conf

exec nginx
