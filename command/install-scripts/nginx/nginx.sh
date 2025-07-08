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
    _package install certbot
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
	    include snippets/certbot_standalone.conf;
	}
	EOF
    # EOF above must be indented with 1 tab character
    # Ensure HTTPs support for default server
    openssl req -x509 -nodes -days 36524 -newkey rsa:4096 \
        -keyout "${_local_etc}/nginx/default_server.key" \
        -out "${_local_etc}/nginx/default_server.crt" \
        -subj "/C=FR/ST=/L=Paris/O=/CN=*"
    # Generate the Diffie-Hellman parameters
    openssl dhparam -out "${_local_etc}/nginx/dhparam.pem" "$nginx_dhparam_numbits"
    # Reusable piece
    cat > "${_local_etc}/nginx/snippets/certbot_standalone.conf" <<-'EOF'
	location ^~ /.well-known/acme-challenge/ {
	    auth_basic off;
	    allow all;
	    access_log /var/log/nginx/certbot.access.log;
	    error_log /var/log/nginx/certbot.error.log;
	    proxy_pass http://localhost:8008/.well-known/acme-challenge/;
	}
	EOF
    # EOF above must be indented with 1 tab character
    cat > "${_local_etc}/nginx/snippets/vhost.conf" <<-EOF
	if (-d /var/www/\$server_name) {
	    include /var/www/\$server_name/nginx*.conf;
	}
	location / {
	    if (!-d /var/www/\$server_name/public) {
	        return 404;
	    }
	    # Ensure redirect to 1. primary domain and 2. HTTPs if available
	    set \$flag_https_s ""; # default to no HTTPs
	    if (-f /usr/local/etc/letsencrypt/live/\$server_name/fullchain.pem) {
	        set \$flag_https_s "s"; # plan redirect if cert exists
	    }
	    if (\$scheme = https) {
	        set \$flag_https_s ""; # remove flag if we're already on HTTPs
	    }
	    set \$flag_https_sn "\$server_name"; # default to primary domain
	    if (\$host = \$server_name) {
	        set \$flag_https_sn ""; # remove flag if already on primary domain
	    }
	    set \$flag_https "\${flag_https_s}\${flag_https_sn}"; # can't concat in if
	    if (\$flag_https != "") { # redirect if at least one flag is not empty
	        return 301 "http\${flag_https_s}://\${server_name}\${request_uri}";
	    }
	    root /var/www/\$server_name/public;
	    access_log /var/log/nginx/vhost-\$server_name.access.log;
	    error_log off;
	}
	include snippets/certbot_standalone.conf;
	EOF
    # EOF above must be indented with 1 tab character
    cat > "${_local_etc}/nginx/snippets/vhost_ssl.conf" <<-EOF
	ssl_certificate ${_local_etc}/letsencrypt/live/\$server_name/fullchain.pem;
	ssl_certificate_key ${_local_etc}/letsencrypt/live/\$server_name/privkey.pem;
	ssl_dhparam ${_local_etc}/nginx/dhparam.pem;
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_prefer_server_ciphers on;
	ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
	ssl_session_timeout 1d;
	ssl_session_cache shared:SSL:50m;
	ssl_stapling on;
	ssl_stapling_verify on;
	add_header Strict-Transport-Security max-age=15768000;
	EOF
    # EOF above must be indented with 1 tab character
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
