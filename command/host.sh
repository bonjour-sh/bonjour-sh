#!/bin/sh
#
# Manage web sites, web apps and web services

_host_command() {
}

_prompt_alias() {
    if [ -n "$1" ]; then
        _aliases="${_aliases} ${1}"
    fi
    read -p "Enter another alias (leave blank to skip): " _another_alias
    if [ "$_another_alias" != "" ]; then # loop
        _prompt_alias "$_another_alias"
    fi
}

_host_command_add() {
    _domain=$(_input 'domain' 'Domain name for the new web service' '' '' "$@")
    _aliases=$(_input 'aliases' 'Domain alias (leave blank to skip)' '' '' "$@")
    if [ "$BONJOUR_NONINTERACTIVE" != "true" ] && [ -n "$_aliases" ]; then
        _prompt_alias
    fi
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 80;
	    include snippets/vhost.conf;
	}
	EOF
    service nginx restart
}

