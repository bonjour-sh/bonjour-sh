#!/bin/sh
#
# The entry point

if [ "$(whoami)" != 'root' ]; then
    echo 'Elevate to root before running this script' >&2
    exit 1
fi

BONJOUR_DEBUG=true
BONJOUR_DIR=$(dirname $(realpath $0))
BONJOUR_OS=$(
    [ "$(uname -s)" = FreeBSD ] && echo freebsd || (
        [ -f /etc/debian_version ] && echo debian || echo unknown
    )
)
export BONJOUR_DEBUG BONJOUR_DIR BONJOUR_OS
printf "$0 in $BONJOUR_DIR on $BONJOUR_OS\n\n"

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

"_${_command_name}_command" "$@"
