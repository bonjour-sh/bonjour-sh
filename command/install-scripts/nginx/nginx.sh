#!/bin/sh
#
# Nginx installer

_local_etc=$(_ local_etc)
_www_root=$(_ www_root)
_www_user=$(_ www_user)
_www_group=$(_ www_group)

_nginx_pre_install_debian() {
    _insert_once /etc/apt/sources.list.d/nginx.org.list <<-EOF
	deb http://nginx.org/packages/debian/ $(lsb_release -sc) nginx
	deb-src http://nginx.org/packages/debian/ $(lsb_release -sc) nginx
	EOF
    wget https://nginx.org/keys/nginx_signing.key -O - | apt-key add -
}

_nginx_pre_install() (
    # Ensures installing newest certbot with newest dependencies
    _package delete certbot
    _package autoremove # ensures dependencies like py311-acme are deleted
)

_nginx_install() (
    _package install nginx
    if [ "${nginx_install_certbot:-false}" = true ]; then
        _package install certbot
    fi
    [ -d "${_local_etc}/nginx/sites-available" ] && rm -rf "${_local_etc}/nginx/sites-available"
    [ -d "${_local_etc}/nginx/sites-enabled" ] && rm -rf "${_local_etc}/nginx/sites-enabled"
    [ -d "${_local_etc}/nginx/modules-available" ] && rm -rf "${_local_etc}/nginx/modules-available"
    [ -d "${_local_etc}/nginx/modules-enabled" ] && rm -rf "${_local_etc}/nginx/modules-enabled"
    [ -d "${_local_etc}/nginx/conf.d" ] && rm -rf "${_local_etc}/nginx/conf.d"
    [ -d "${_local_etc}/nginx/snippets" ] && rm -rf "${_local_etc}/nginx/snippets"
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
    # Get the Diffie-Hellman parameters file
    case "$nginx_dhparam" in
        http://*|https://*) # received a URL to fetch the file from
            curl -o "${_local_etc}/nginx/dhparam.pem" "$nginx_dhparam"
            ;;
        /*) # received path to existing file
            cp "$nginx_dhparam" "${_local_etc}/nginx/dhparam.pem"
            ;;
        [0-9]*) # received numbits - generate a new file
            openssl dhparam -out "${_local_etc}/nginx/dhparam.pem" "$nginx_dhparam"
            ;;
    esac
    if ! openssl dhparam -in "${_local_etc}/nginx/dhparam.pem" > /dev/null 2>&1; then
        echo "Invalid DH params file (received ${nginx_dhparam})" >&2
        return 1
    fi
    # Reusable piece for Certbot HTTP-01 challenge
    if [ "${nginx_install_certbot:-false}" = true ]; then
        cat > "${_local_etc}/nginx/snippets/certbot_standalone.conf" <<-'EOF'
		location ^~ /.well-known/acme-challenge/ {
		    auth_basic off;
		    allow all;
		    access_log /var/log/nginx/certbot.access.log;
		    error_log /var/log/nginx/certbot.error.log;
		    proxy_pass http://localhost:8008/.well-known/acme-challenge/;
		}
		EOF
        # EOF above must be indented with 2 tab characters
    else
        : > "${_local_etc}/nginx/snippets/certbot_standalone.conf"
    fi
    cat > "${_local_etc}/nginx/snippets/vhost.conf" <<-EOF
	location / {
	    if (!-d ${_www_root}/\$server_name/public) {
	        return 404;
	    }
	    # Ensure redirect to 1. primary domain and 2. HTTPs if available
	    set \$flag_https_s ""; # default to no HTTPs
	    if (-f ${_local_etc}/nginx/conf.d/vhost_\${server_name}_443.conf) {
	        set \$flag_https_s "s"; # plan redirect if HTTPs config exists
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
	    root ${_www_root}/\$server_name/public;
	    index index.php index.html index.htm;
	    access_log /var/log/nginx/vhost-\$server_name.access.log;
	    error_log off;
	}
	include snippets/certbot_standalone.conf;
	EOF
    # EOF above must be indented with 1 tab character
    cat > "${_local_etc}/nginx/snippets/vhost_ssl.conf" <<-EOF
	# Server name is evaluated at request after privilege drop. So _www_user may
	# not have read permissions to SSL key in LE archive, unless specifically allowed
	#ssl_certificate ${_www_root}/\$server_name/ssl/cert;
	#ssl_certificate_key ${_www_root}/\$server_name/ssl/key;
	ssl_dhparam ${_local_etc}/nginx/dhparam.pem;
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_prefer_server_ciphers on;
	ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
	ssl_session_timeout 1d;
	ssl_session_cache shared:SSL:50m;
	ssl_stapling off;
	ssl_stapling_verify off;
	add_header Strict-Transport-Security max-age=15768000;
	EOF
    # EOF above must be indented with 1 tab character
    # Setup for future Nginx backends
    mkdir "${_local_etc}/nginx/snippets/backend" # folder where we keep snippets
    cat > "${_local_etc}/nginx/snippets/backend/README.md" <<-EOF
	Each file here is a configuration for a specific type of backend for Nginx.
	Usage: include required snippet into website/host configuration.
	
	Example 1: create a symlink
	
	    ln -s ${_local_etc}/nginx/snippets/backend/\$backend.conf ${_www_root}/\$server_name/nginx.backend.conf
	
	Example 2: use `include` statement
	
	    echo 'include ${_local_etc}/nginx/snippets/backend/\$backend.conf;' > ${_www_root}/\$server_name/nginx.backend.conf
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
