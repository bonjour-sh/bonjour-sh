#!/bin/sh
#
# PHP installer

_local_etc=$(_ local_etc)
_www_root=$(_ www_root)
_www_user=$(_ www_user)
_www_group=$(_ www_group)

_php_pre_install_debian() (
    _insert_once \
        "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
        /etc/apt/sources.list.d/packages.sury.org.list
    wget -O /etc/apt/trusted.gpg.d/packages.sury.org.gpg https://packages.sury.org/php/apt.gpg
    apt-get update
)

_php_install_debian() (
    _package install "php${php_version}-cli"
    _package install "php${php_version}-common"
    _package install "php${php_version}-fpm"
)

_php_install_freebsd() (
    _package install "php${php_version}"
)

_php_install() {
    for _mod in mysql curl gd mcrypt intl json bcmath imap mbstring xml opcache zip sqlite3; do
        _package install "php${php_version}-${_mod}"
    done
    # Find the WWW pool config
    _www_conf=$(find "$_local_etc" -path "*/php*fpm*" -type f -name 'www.conf' | head -n 1)
    _config "$_www_conf" ';' '=' <<-EOF
	listen $php_socket_path
	listen.owner $_www_user
	listen.group $_www_group
	EOF
    # EOF above must be indented with 1 tab character
    cat >> "${_local_etc}/nginx/snippets/backend/php.conf" <<-EOF
	location ~ \.php {
	    root ${_www_root}/\$server_name/public;
	    include fastcgi_params;
	    keepalive_timeout 0;
	    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
	    fastcgi_index index.php;
	    fastcgi_pass unix:${php_socket_path};
	}
	EOF
    # EOF above must be indented with 1 tab character
}

_php_post_install() (
    # Find PHP init script path in rc*.d within system's etc folder
    _path=$(find "$_local_etc" -path '*/rc*.d/*' \( -type f -o -type l \) -name '*php*' | head -n 1)
    # The rc*.d files on some systems are symlinks, get real init script path
    _path=$(realpath "$_path")
    # Get PHP-fpm service identifier from init path
    _name=$(basename "$_path")
    # Enable and start
    _at_boot enable $_name
    service $_name restart
    service nginx restart
)
