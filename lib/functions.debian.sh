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

# _at_boot - OS-agnostic wrapper to enable/disable a service at boot
# Depending on ACTION:
# - SERVICE starting up at boot will be enabled or disabled;
# - if ACT_IMMEDIATELY is true, SERVICE will be started or stopped immediately
# Usage: _at_boot ACTION SERVICE ACT_IMMEDIATELY
# Arguments:
#   $1 - ACTION: enable|disable
#   $2 - SERVICE: service name
#   $3 - ACT_IMMEDIATELY: true to start/stop (depending on ACTION) the service now
_at_boot() (
    systemctl "$1" "$2"
    if [ "_$3" = "_true" ]; then
        service "$2" $( [ "_$1" = "_enable" ] && echo start || echo stop )
    fi
)
