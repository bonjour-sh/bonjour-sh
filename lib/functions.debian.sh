#!/bin/sh
#
# Debian-specific implementation for ./functions.sh

_package() {
    case $1 in
        install)
            DEBIAN_FRONTEND=noninteractive apt-get install -q -y --no-install-recommends -o Dpkg::Options::="--force-confnew" $2
            ;;
        purge)
            apt-get purge -y $2*
            ;;
        upgrade)
            apt-get upgrade -y
            ;;
        autoremove)
            apt-get autoremove -y
            ;;
    esac
}

# _at_boot - OS-agnostic wrapper to enable/disable a service at boot
# Depending on ACTION:
# - SERVICE starting up at boot will be enabled or disabled;
# - if ACT_IMMEDIATELY is true, SERVICE will be started or stopped immediately
# Usage: _at_boot ACTION SERVICE ACT_IMMEDIATELY
# Arguments:
#   $1 - ACTION: enable|disable
#   $2 - SERVICE: service name
#   $3 - ACT_IMMEDIATELY: true to start/stop (depending on ACTION) the service now
_at_boot() (
    systemctl "$1" "$2"
    if [ "_$3" = "_true" ]; then
        service "$2" $( [ "_$1" = "_enable" ] && echo start || echo stop )
    fi
)

# _firewall - OS-agnostic wrapper to manage firewall
# Usage: _firewall RULE-NAME STATE SRC DIRECTION DST
# Arguments:
#   $1 - RULE-NAME: name for rule(set), used in filename for persisting
#   $2 - STATE: allow|deny|flush
#   $3 - SRC: see DST below
#   $4 - DIRECTION: in|out
#   $5 - DST: IP[/MASK][:PORT], e.g. 1.2.3.4, 1.2.3.4:56, 1.2.3.4/24:56 etc.
_firewall() (
    _file="/etc/iptables-bonjour/${1}.sh"
    # Determine target
    case $2 in
        allow)
            _target='ACCEPT'
            ;;
        deny)
            _target='DROP'
            ;;
        flush)
            : > "$_file"
            return
            ;;
    esac
    # Determine name of iptables chain we're working with
    [ "$4" = 'out' ] && _chain=OUTPUT || _chain=INPUT
    # Parse IP[/MASK] and PORT out of SRC and DST
    IFS=':' read -r _src_host _src_port <<-EOF
	$3
	EOF
    IFS=':' read -r _dst_host _dst_port <<-EOF
	$5
	EOF
    # EOFs above must be indented with 1 tab character
    # Build src line
    _src_line=''
    if [ -n "$_src_host" ]; then
        _src_line="${_src_line} -s ${_src_host}"
    fi
    if [ -n "$_src_port" ]; then
        _src_line="${_src_line} --sport ${_src_port}"
    fi
    _dst_line=''
    if [ -n "$_dst_host" ]; then
        _dst_line="${_dst_line} -d ${_dst_host}"
    fi
    if [ -n "$_dst_port" ]; then
        _dst_line="${_dst_line} --dport ${_dst_port}"
    fi
    $BONJOUR_DEBUG && cat >&2 <<-EOF
	    @          $@
	    file       $_file
	    chain      $_chain
	    src
	        host   $_src_host
	        port   $_src_port
	    dst
	        host   $_dst_host
	        port   $_dst_port
	EOF
    # EOF above must be indented with 1 tab character
    _rule="iptables -A ${_chain} -p tcp ${_src_line} ${_dst_line} -j ${_target}"
    _insert_once "$_rule" "$_file"
)
