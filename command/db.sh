#!/bin/sh
#
# Manage databases and users

_db_command_list() (
    _root_pass=$(bonjour env var mariadb_root_password)
    [ -z "$_root_pass" ] && { echo 'mariadb_root_password not defined in ~/.bonjour.env'; exit 1; }
    mysql -uroot -p${_root_pass} -e "SHOW databases;"
)

_db_command_add() (
    _root_pass=$(bonjour env var mariadb_root_password)
    [ -z "$_root_pass" ] && { echo 'mariadb_root_password not defined in ~/.bonjour.env'; exit 1; }
    _name=$(_input 'name' 'New database name' '' '' "$@")
    [ -z "$_name" ] && { echo 'Provide database name'; exit 1; }
    mysql -uroot -p${_root_pass} -e "CREATE DATABASE \`${_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
)

_db_command_user() (
    _root_pass=$(bonjour env var mariadb_root_password)
    [ -z "$_root_pass" ] && { echo 'mariadb_root_password not defined in ~/.bonjour.env'; exit 1; }
    case $1 in
        list)
            mysql -uroot -p${_root_pass} -e "SELECT u.User,u.Host,d.Db FROM mysql.user AS u LEFT JOIN mysql.db AS d ON u.User = d.User AND u.Host = d.Host ORDER BY u.User, u.Host, d.Db;"
            ;;
        add)
            _name=$(_input 'name' 'New user name' '' '' "$@")
            [ -z "$_name" ] && { echo 'Provide user name'; exit 1; }
            _pass=$(_input 'password' 'New user password' "$(_random_string 24)" '' "$@")
            _remote=$(_input 'remote' 'Allow remote' 'true' '' "$@")
            _schema=$(_input 'schema' 'Add to schema' '*' \
                'Providing schema name grants privileges on that schema only; * adds to all schemas' "$@")
            [ "_$_remote" = '_true' ] && _host='%' || _host='localhost'
            mysql -uroot -p${_root_pass} -e "CREATE USER '${_name}'@'${_host}' IDENTIFIED BY '${_pass}';"
            mysql -uroot -p${_root_pass} -e "GRANT ALL PRIVILEGES ON ${_schema}.* TO '${_name}'@'${_host}' WITH GRANT OPTION;"
            ;;
        drop)
            _name=$(_input 'name' 'User to drop' '' '' "$@")
            [ -z "$_name" ] && { echo 'Provide user name'; exit 1; }
            _hosts=$(mysql -uroot -p${_root_pass} -N -B -e "SELECT Host FROM mysql.user WHERE User='${_name}';")
            for _host in $_hosts; do
                _account="'${_name}'@'${_host}'"
                mysql -uroot -p${_root_pass} -e "DROP USER ${_account};" && echo "Dropped ${_account}"
            done
            ;;
    esac
)
