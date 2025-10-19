#!/bin/sh
#
# Icecast installer - Debian specifics

# OS-specific default for icecast_user omitted in .icecast.env
icecast_user_default='icecast2' # default for respective _input prompt

# Unlike FreeBSD and CentOS, Debian package name says '2'
_icecast_package_name='icecast2'
