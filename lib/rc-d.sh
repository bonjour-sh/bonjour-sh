#!/bin/sh

: "${name:?}"
: "${cmd_start:?}"
: "${cmd_stop:?}"
: "${cmd_restart:="$cmd_stop && $cmd_start"}"

echo "Running shared rc-d.sh for $name via $0"

case "$1" in
    start|faststart)
        echo "Starting $name"
        sh -c "$cmd_start"
        ;;
    stop)
        echo "Stopping $name"
        sh -c "$cmd_stop"
        ;;
    restart)
        echo "Restarting $name"
        sh -c "$cmd_restart"
        ;;
    status)
        if [ -n "$cmd_status" ]; then
            echo "Checking status of $name"
            sh -c "$cmd_status"
        else
            echo "Status not implemented for $name"
        fi
        ;;
    *)
        $(bonjour env log "Shared rc-d.sh for '$name' received unsupported '$1'")
        echo "Usage: service $name {start|stop|restart|status}"
        exit 1
    ;;
esac
