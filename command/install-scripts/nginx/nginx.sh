#!/bin/sh
#
# Nginx installer

_local_etc=$(_ local_etc)
_www_root=$(_ www_root)
_www_user=$(_ www_user)
_www_group=$(_ www_group)

_nginx_pre_install_debian() {
    _debian_codename=$(lsb_release -sc)
    echo "deb http://nginx.org/packages/debian/ ${_debian_codename} nginx" >> /etc/apt/sources.list
    echo "deb-src http://nginx.org/packages/debian/ ${_debian_codename} nginx" >> /etc/apt/sources.list
    wget https://nginx.org/keys/nginx_signing.key -O - | apt-key add -
}

_nginx_pre_install() {
    [ -d "${_local_etc}/nginx/sites-available" ] && rm -rf "${_local_etc}/nginx/sites-available"
    [ -d "${_local_etc}/nginx/sites-enabled" ] && rm -rf "${_local_etc}/nginx/sites-enabled"
    [ -d "${_local_etc}/nginx/conf.d" ] && rm -rf "${_local_etc}/nginx/conf.d"
    [ -d "${_local_etc}/nginx/snippets" ] && rm -rf "${_local_etc}/nginx/snippets"
}

_nginx_install() (
    _package install nginx
    # Whole files included in main nginx.conf as conf.d/*.conf
    mkdir -p "${_local_etc}/nginx/conf.d"
    # Reusable parts to be included in individual configs
    mkdir -p "${_local_etc}/nginx/snippets"
    # Create WWW root
    mkdir -p "$_www_root"
    # Main
    cat > "${_local_etc}/nginx/nginx.conf" <<-EOF
	user ${_www_user};
	worker_processes 4;
	pid /var/run/nginx.pid;
	events {
	    worker_connections 1024;
	    use epoll;
	    multi_accept on;
	}
	http {
	    server_names_hash_bucket_size 128;
	    client_max_body_size 32m;
	    include mime.types;
	    default_type application/octet-stream;
	    charset utf-8;
	    sendfile on;
	    keepalive_timeout 65;
	    server_tokens off;
	    gzip on;
	    gzip_disable "msie6";
	    gzip_vary on;
	    gzip_proxied any;
	    gzip_comp_level 6;
	    gzip_buffers 16 8k;
	    gzip_http_version 1.1;
	    gzip_min_length 256;
	    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript application/x-javascript application/vnd.ms-fontobject application/x-font-ttf font/opentype image/svg+xml image/x-icon application/x-font-opentype application/x-font-truetype font/eot font/otf image/vnd.microsoft.icon;
	    include ${_local_etc}/nginx/conf.d/*.conf;
	}
	EOF
    # EOF above must be indented with 1 tab character
    # Default server
    cat > "${_local_etc}/nginx/conf.d/default_server.conf" <<-EOF
	server {
	    server_name _;
	    listen 80 default_server;
	    listen 443 ssl default_server;
	    ssl_certificate ${_local_etc}/nginx/default_server.crt;
	    ssl_certificate_key ${_local_etc}/nginx/default_server.key;
	    location / {
	        access_log /var/log/nginx/default_server.access.log;
	        error_log /var/log/nginx/default_server.error.log;
	        return 444;
	    }
	}
	EOF
    # EOF above must be indented with 1 tab character
    # Ensure HTTPs support for default server
    openssl req -x509 -nodes -days 36524 -newkey rsa:4096 \
        -keyout "${_local_etc}/nginx/default_server.key" \
        -out "${_local_etc}/nginx/default_server.crt" \
        -subj "/C=FR/ST=/L=Paris/O=/CN=*"
    # Make sure the permissions are correct
    chown -R "${_www_user}:${_www_group}" "${_local_etc}/nginx"
    chown -R "${_www_user}:${_www_group}" "/var/log/nginx"
    chown -R "${ssh_user}:${_www_group}" "$_www_root"
    chmod g+s "$_www_root"
    # Enable and start
    _at_boot enable nginx true
)

_nginx_uninstall() {
    _package uninstall $(_ package_nginx)
    rm -rf "${_local_etc}/nginx"
}
