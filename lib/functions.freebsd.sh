#!/bin/sh
#
# FreeBSD-specific implementation for ./functions.sh

_package() {
    case $1 in
        install)
            pkg install -y $2
            ;;
        purge)
            pkg delete $2
            ;;
        upgrade)
            pkg upgrade
            ;;
        autoremove)
            pkg autoremove
            ;;
    esac
}
