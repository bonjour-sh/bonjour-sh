#!/bin/sh

[ -d ~/bonjour-sh ] && rm -rf ~/bonjour-sh
[ -d ~/bonjour-sh-master ] && rm -rf ~/bonjour-sh-master

OUT="/tmp/bonjour-sh.tar.gz"
URL="https://github.com/bonjour-sh/bonjour-sh/archive/refs/heads/master.tar.gz"
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$OUT" "$URL"
elif command -v fetch >/dev/null 2>&1; then
    fetch -o "$OUT" "$URL"
else
    echo "Error: cannot download installer; both curl and fetch unavailable" >&2
    exit 1
fi

tar -xzf /tmp/bonjour-sh.tar.gz -C ~
mv ~/bonjour-sh-master ~/bonjour-sh
chmod +x ~/bonjour-sh/bonjour.sh
[ -d /usr/local/bin ] || mkdir -p /usr/local/bin
ln -sf "$(realpath ~)/bonjour-sh/bonjour.sh" /usr/local/bin/bonjour

bonjour help
