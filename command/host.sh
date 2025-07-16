#!/bin/sh
#
# Manage web sites, web apps and web services

_prompt_alias() {
    if [ -n "$1" ]; then
        _aliases="${_aliases} ${1}"
    fi
    read -p "Enter another alias (leave blank to skip): " _another_alias
    if [ "$_another_alias" != "" ]; then # loop
        _prompt_alias "$_another_alias"
    fi
}

_host_command_list() (
    for _vhost in $(_ local_etc)/nginx/conf.d/vhost_*_*.conf; do
        IFS=_ read -r _prefix _host _port <<-EOF
		$(basename $_vhost '.conf')
		EOF
        printf 'http%s://%s\n' "$([ "$_port" = '443' ] && echo 's')" "$_host"
    done
)

_host_command_add() {
    _domain=$(_input 'domain' 'Domain name for the new web service' '' '' "$@")
    if [ -z "$_domain" ]; then
        printf 'Can not continue without a domain name\n'
        return 1
    fi
    _aliases=$(_input 'aliases' 'Domain alias (leave blank to skip)' '' '' "$@")
    if [ "$BONJOUR_NONINTERACTIVE" != "true" ] && [ -n "$_aliases" ]; then
        _prompt_alias
    fi
    _web_root="$(_ www_root)/${_domain}"
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 80;
	    include ${_web_root}/nginx*.conf;
	    include snippets/vhost.conf;
	}
	EOF
    mkdir -p "${_web_root}"
    mkdir -p "${_web_root}/public"
    service nginx restart
    _certbot_certonly "${_domain} ${_aliases}"
    if [ $? -ne 0 ]; then
        echo "Certbot failed. Aborting."
        rm "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf"
        return 1
    fi
    mkdir -p "${_web_root}/ssl"
    ln -s "$(_ local_etc)/letsencrypt/live/${_domain}/fullchain.pem" "${_web_root}/ssl/cert"
    ln -s "$(_ local_etc)/letsencrypt/live/${_domain}/privkey.pem" "${_web_root}/ssl/key"
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_443.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 443 ssl;
	    # No variables means Nginx preloads certs on start with root privileges
	    ssl_certificate ${_web_root}/ssl/cert;
	    ssl_certificate_key ${_web_root}/ssl/key;
	    include ${_web_root}/nginx*.conf;
	    include snippets/vhost.conf;
	    include snippets/vhost_ssl.conf;
	}
	EOF
    service nginx restart
}

