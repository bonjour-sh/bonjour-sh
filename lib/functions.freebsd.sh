#!/bin/sh
#
# FreeBSD-specific implementation for ./functions.sh

_package() {
    case $1 in
        install)
            pkg install -y -f $2
            ;;
        purge)
            pkg delete -y -f $2*
            ;;
        upgrade)
            pkg upgrade -y
            ;;
        autoremove)
            pkg autoremove -y
            ;;
    esac
}

