#!/bin/sh
#
# Debian-specific implementation for ./functions.sh

_package() {
    case $1 in
        install)
            DEBIAN_FRONTEND=noninteractive apt-get install -q -y --no-install-recommends -o Dpkg::Options::="--force-confnew" $2
            ;;
        uninstall)
            apt-get purge $2
            ;;
        upgrade)
            apt-get upgrade
            ;;
        autoremove)
            apt-get autoremove
            ;;
    esac
}
