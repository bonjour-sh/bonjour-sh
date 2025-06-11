#!/bin/sh
#
# Debian-specific implementation for ./functions.sh

_package() {
    case $1 in
        install)
            DEBIAN_FRONTEND=noninteractive apt-get install -q -y --no-install-recommends -o Dpkg::Options::="--force-confnew" $2
            ;;
        purge)
            apt-get purge -y $2*
            ;;
        upgrade)
            apt-get upgrade -y
            ;;
        autoremove)
            apt-get autoremove -y
            ;;
    esac
}
