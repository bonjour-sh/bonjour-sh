#!/bin/sh
#
# Allows external commands to run our internal functions

_func_command() {
    _func="_${1}" # shorthand to function name
    shift 1 # drop first argument; so we pass arguments without function name
    if type "$_func" 2>/dev/null | grep -q 'function'; then
        "$_func" "$@"
    fi
}

