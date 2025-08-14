#!/bin/sh

curl -L -o /tmp/bonjour-sh.tar.gz https://github.com/bonjour-sh/bonjour-sh/archive/refs/heads/master.tar.gz
tar -xzf /tmp/bonjour-sh.tar.gz -C ~
mv ~/bonjour-sh-master ~/bonjour-sh
chmod +x ~/bonjour-sh/bonjour.sh
ln -sf "$(realpath ~)/bonjour-sh/bonjour.sh" /usr/local/bin/bonjour
