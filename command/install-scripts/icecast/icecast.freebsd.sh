#!/bin/sh
#
# Icecast installer - FreeBSD specifics

# OS-specific default for icecast_user omitted in .icecast.env
icecast_user_default='icecast' # default for respective _input prompt

# FreeBSD keeps Icecast config in /usr/local/etc, no subfolder (unlike Debian)
_icecast_config_path="$(_ local_etc)/icecast.xml"
