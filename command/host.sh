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

_host_command_home() (
    printf '%s' "$(_ www_root)/${1}"
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
    _web_home="$(_host_command_home ${_domain})"
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 80;
	    include ${_web_home}/nginx*.conf;
	    include snippets/vhost.conf;
	}
	EOF
    mkdir -p "${_web_home}"
    mkdir -p "${_web_home}/public"
    if [ ! -f "${_web_home}/ssl/cert" ] || [ ! -f "${_web_home}/ssl/key" ]; then
        if [ "$(bonjour env var nginx_install_certbot)" = 'true' ]; then
            service nginx restart
            _certbot_certonly "${_domain} ${_aliases}"
            if [ $? -ne 0 ]; then
                echo "Certbot failed. Aborting."
                rm "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_80.conf"
                return 1
            fi
            mkdir -p "${_web_home}/ssl"
            ln -fs "$(_ local_etc)/letsencrypt/live/${_domain}/fullchain.pem" "${_web_home}/ssl/cert"
            ln -fs "$(_ local_etc)/letsencrypt/live/${_domain}/privkey.pem" "${_web_home}/ssl/key"
        fi
    fi
    if [ ! -f "${_web_home}/ssl/cert" ] || [ ! -f "${_web_home}/ssl/key" ]; then
        return 0
    fi
    cat > "$(_ local_etc)/nginx/conf.d/vhost_${_domain}_443.conf" <<-EOF
	server {
	    server_name ${_domain} ${_aliases};
	    listen 443 ssl;
	    # No variables means Nginx preloads certs on start with root privileges
	    ssl_certificate ${_web_home}/ssl/cert;
	    ssl_certificate_key ${_web_home}/ssl/key;
	    include ${_web_home}/nginx*.conf;
	    include snippets/vhost.conf;
	    include snippets/vhost_ssl.conf;
	}
	EOF
    chown -R "$ssh_user" "${_web_home}"
    service nginx restart
}
