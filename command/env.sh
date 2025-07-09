#!/bin/sh
#
# Provides information about OS and the environment

_env_command_os() {
    echo $BONJOUR_OS
}

_env_command_var() {
    echo $(_ $1)
}

_env_command_package() (
    echo $(_package_resolve $1)
)
