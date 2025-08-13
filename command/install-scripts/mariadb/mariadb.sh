#!/bin/sh
#
# MariaDB installer

_mariadb_install() (
    _package install mariadb-server
)

_mariadb_post_install_debian() (
    _at_boot enable mariadb
)

_mariadb_post_install_freebsd() {
    _at_boot enable mysql
}
