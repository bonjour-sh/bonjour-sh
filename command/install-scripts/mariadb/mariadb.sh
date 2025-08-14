#!/bin/sh
#
# MariaDB installer

mariadb_root_password_default=$(_random_string 24)

_mariadb_install() (
    _package install mariadb-server
    mysqladmin -u root password "${mariadb_root_password}"
    _config "$(_ local_etc)/mysql/my.cnf" '#' '=' 'port' "${mariadb_port}"
    if [ -n "$whitelisted_hosts" ]; then
        _firewall 'mariadb-restrict' flush
        for _whitelisted_host in $whitelisted_hosts; do
            _firewall 'mariadb-restrict' allow "$_whitelisted_host" in ":${mariadb_port}"
            _firewall 'mariadb-restrict' allow ":${mariadb_port}" out "$_whitelisted_host"
        done
        _firewall 'mariadb-restrict' deny '' in ":${mariadb_port}"
        _firewall 'mariadb-restrict' deny ":${mariadb_port}" out ''
    fi
)

_mariadb_post_install_debian() (
    _package install mariadb-backup # not bundled on Debian so install separately
    _at_boot enable mariadb
)

_mariadb_post_install_freebsd() {
    _at_boot enable mysql
}
