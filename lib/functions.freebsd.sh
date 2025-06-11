#!/bin/sh
#
# FreeBSD-specific implementation for ./functions.sh

LOCAL_ETC='/usr/local/etc'
export LOCAL_ETC

_package() {
    case $1 in
        install)
            pkg install -y $2
            ;;
        purge)
            pkg delete $2*
            ;;
        upgrade)
            pkg upgrade -y
            ;;
        autoremove)
            pkg autoremove
            ;;
    esac
}

