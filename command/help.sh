#!/bin/sh
#
# Provides help

_help_command() {
    printf 'OS: %s\nLocation: %s\n' "$(bonjour env os)" "$(bonjour env path)"
    printf 'Usage: bonjour <command> <...>\nAvailable commands:\n'
    for _command in $(bonjour env path)/command/*.sh; do
        printf -- '- %s\n' "$(basename $_command .sh)"
    done
    printf 'Example: bonjour <command> help\n'
}
