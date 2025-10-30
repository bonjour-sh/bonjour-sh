#!/bin/sh
#
# Icecast installer

_local_etc=$(_ local_etc)

# OS-specific variables
# Can be defined in ./icecast.$BONJOUR_OS.sh, else default to below
if [ -z "$_icecast_package_name" ]; then
    # Debian uses icecast2; default to icecast (FreeBSD/CentOS)
    _icecast_package_name='icecast'
fi
if [ -z "$_icecast_config_path" ]; then
    # Default to having icecast.xml inside subfolder like on Debian
    _icecast_config_path="${_local_etc}/${_icecast_package_name}/icecast.xml"
fi

_icecast_install() {
    _package install "$_icecast_package_name"
    set -x
    # Copy config from sample, if any
    if [ -f "${_icecast_config_path}.sample" ]; then
        mv "${_icecast_config_path}.sample" "$_icecast_config_path"
    fi
    _groupadd_once "$icecast_group"
    _home="/home/${icecast_user}"
    _useradd_once "$icecast_user" -g "$icecast_group" -d "$_home"
    # Make sure <changeowner> is NOT commented out, Icecast will not run as root
    # To uncomment with xmlstarlet, delete everything and re-create
    # 1. delete <security> block including tags that may or may not be commented
    # 2. re-create <security>
    # 3. insert <chroot> and set it to 0
    # 4. insert new, clean <changeowner>
    # 5. and 6. set user and group
    # 7. ensure Icecast binds to all interfaces by default
    xmlstarlet ed \
        -d '/icecast/security' \
        -s '/icecast' -t elem -n 'security' -v '' \
        -s '/icecast/security' -t elem -n 'chroot' -v '0' \
        -s '/icecast/security' -t elem -n 'changeowner' -v '' \
        -s '/icecast/security/changeowner' -t elem -n 'user' -v "$icecast_user" \
        -s '/icecast/security/changeowner' -t elem -n 'group' -v "$icecast_group" \
        -u '/icecast/listen-socket/bind-address' -v '0.0.0.0' \
        "$_icecast_config_path" > "${_icecast_config_path}.tmp"
    mv "${_icecast_config_path}.tmp" "$_icecast_config_path"
    # Make sure user can write to log directory, else Icecast will not run
    _icecast_logdir=$(xmlstarlet sel -t -v '/icecast/paths/logdir' "$_icecast_config_path" 2>/dev/null)
    if [ -n "$_icecast_logdir" ]; then
        [ -d "$_icecast_logdir" ] || mkdir -p "$_icecast_logdir"
        chown -R "${icecast_user}:${icecast_group}" "$_icecast_logdir"
    fi
    if [ "${icecast_behind_nginx:-false}" = true ]; then
        # Bind Icecast to 127.0.0.1 only (Nginx proxies to public)
        xmlstarlet ed \
            -u '/icecast/listen-socket/bind-address' -v '127.0.0.1' \
            "$_icecast_config_path" > "${_icecast_config_path}.tmp"
        mv "${_icecast_config_path}.tmp" "$_icecast_config_path"
        # Add HTTP proxy for listeners; used in VHOST configurations incl. SSL
        cat > "${_local_etc}/nginx/snippets/backend/icecast.conf" <<-EOF
		# Tip: front Icecast with Nginx, get host management and SSL functionality
		# - create a new host and use this snippet as backend - see ./README.md
		# - in icecast.xml, having icecast/listen-socket/bind-address=127.0.0.1
		#   ensures Icecast can only be accessed through Nginx
		location ~ ^/ { # can't be location / because it's already used
		    proxy_pass http://127.0.0.1:8000;
		    proxy_redirect off;
		    proxy_set_header Host \$host;
		    proxy_set_header X-Real-IP \$remote_addr;
		    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		}
		EOF
        # Add STREAM proxy for sources (including HTTP 1.0); expose 8000 port
        cat > "${_local_etc}/nginx/conf.stream.d/default_icecast.conf" <<-EOF
		# Sources don't reach Icecast when behind http{} proxy, has to be stream{}
		server {
		    server_name default_icecast;
		    listen 8000 default_server;
		    proxy_pass 127.0.0.1:8000;
		}
		EOF
    fi
}

_icecast_post_install() {
    set -x
    # Enable and start
    _at_boot enable "$_icecast_package_name" true
}

_icecast_uninstall() {
    _package uninstall "$_icecast_package_name"
}
