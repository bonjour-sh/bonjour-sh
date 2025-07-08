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
    _web_root="$(_ www_root)/${_domain}"
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 80;
	    include snippets/vhost.conf;
	}
	EOF
    mkdir -p "${_web_root}"
    mkdir -p "${_web_root}/public"
    service nginx restart
    _certbot_certonly "${_domain} ${_aliases}"
    if [ $? -ne 0 ]; then
        echo "Certbot failed. Aborting."
        return 1
    fi
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_443.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 443 ssl;
	    include snippets/vhost.conf;
	    include snippets/vhost_ssl.conf;
	}
	EOF
    service nginx restart
}

