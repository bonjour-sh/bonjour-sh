#!/bin/sh
#
# The entry point

if [ "$(whoami)" != 'root' ]; then
    echo 'Elevate to root before running this script' >&2
    exit 1
fi

BONJOUR_DEBUG="${BONJOUR_DEBUG:-false}"
BONJOUR_NONINTERACTIVE="${BONJOUR_NONINTERACTIVE:-false}"
BONJOUR_DIR=$(dirname $(realpath $0))
BONJOUR_OS=
case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    freebsd) BONJOUR_OS=freebsd ;;
    linux)
        if [ -f /etc/debian_version ]; then
            BONJOUR_OS=debian
        fi
        ;;
esac
if [ -z "$BONJOUR_OS" ]; then
    echo 'Unknown OS' >&2
    exit 1
fi
export BONJOUR_DEBUG BONJOUR_DIR BONJOUR_OS

printf "+------------------------------------------+\n" >&2
printf "| %-40s |\n" "`date`" >&2
printf "|                                          |\n" >&2
printf "|`tput bold` %-40s `tput sgr0`|\n" "$0 on $BONJOUR_OS" >&2
printf "+------------------------------------------+\n\n" >&2

# Read our configuration, if any
if [ -f "${HOME}/.bonjour.env" ]; then
    . "${HOME}/.bonjour.env"
fi
# Include reusable functions
if [ -f "${BONJOUR_DIR}/lib/functions.${BONJOUR_OS}.sh" ]; then
    . "${BONJOUR_DIR}/lib/functions.${BONJOUR_OS}.sh"
fi
. "${BONJOUR_DIR}/lib/functions.sh"

_command_name="$1"
shift 1
if [ -z "$_command_name" ]; then
    echo 'Provide command' >&2
    exit 1
fi
# Check if the requested command exists
if [ ! -f "${BONJOUR_DIR}/command/${_command_name}.sh" ]; then
    echo "Requested command ${_command_name} was not found"
    exit 1
fi

# Include the requested command file
if [ -f "${BONJOUR_DIR}/command/${_command_name}.${BONJOUR_OS}.sh" ]; then
    . "${BONJOUR_DIR}/command/${_command_name}.${BONJOUR_OS}.sh"
fi
. "${BONJOUR_DIR}/command/${_command_name}.sh"
# See if a specific subcommand was requested
if [ -n "$1" ] && [ "_$1" = "_$(printf "%s" "$1" | tr -dc '[:alnum:]')" ]; then
    _subcommand_name="$1"
    # First argument is subcommand name. Don't pass it to subcommand function.
    shift 1
    "_${_command_name}_command_${_subcommand_name}" "$@"
else
    "_${_command_name}_command" "$@"
fi
