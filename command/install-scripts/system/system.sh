#!/bin/sh
#
# Base system installer

# Hijack certain prompts
_system_prompt_server_ip() (
    _detected_ip=$(_get_public_ip)
    _provided_ip=$(_input 'server_ip' 'Public IP address' "$_detected_ip" '' "$@")
    if ! { echo "$_provided_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }; then
        echo "${_provided_ip} does not look like a valid IPv4 address" >&2
        _system_prompt_server_ip "$@"
    fi
    ping -c 1 "${_provided_ip}">/dev/null 2>&1
    if [ "$?" -gt "0" ]; then
        echo "${_provided_ip} is not connectable." >&2
        _system_prompt_server_ip "$@"
        return
    fi
    echo "$_provided_ip"
)
_system_prompt_ssh_pubkey() (
    _provided_pubkey=$(_input \
        'ssh_pubkey' \
        'Paste your public key' \
        '' \
        'The public key you will be connecting to the server with. Will be validated before proceeding.' \
        "$@" \
    )
    # Make sure the provided public key is valid
    printf "$_provided_pubkey" | ssh-keygen -l -f - > /dev/null
    if [ $? -ne 0 ]; then
        printf "The public key you provided is not valid.\n" >&2
        _system_prompt_ssh_pubkey "$@"
        return
    fi
    printf "$_provided_pubkey"
)

_system_pre_install_debian() {
    _package install apt-transport-https
    _package install ca-certificates
    _package install lsb-release
    # Update sources.list
    _debian_codename=$(lsb_release -sc)
    cat /dev/null > /etc/apt/sources.list
    echo "deb http://httpredir.debian.org/debian ${_debian_codename} main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://httpredir.debian.org/debian ${_debian_codename}-backports main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://security.debian.org/ ${_debian_codename}/updates main contrib non-free" >> /etc/apt/sources.list
    for k in $(apt-get update 2>&1|grep -o NO_PUBKEY.*|sed 's/NO_PUBKEY //g');do echo "key: $k";gpg --recv-keys $k;gpg --recv-keys $k;gpg --armor --export $k|apt-key add -;done
    _package install debian-archive-keyring
    apt-get update
}

_system_pre_install_freebsd() (
    _at_boot enable ntpd true
    sysrc ntpd_sync_on_start=YES
    # Create basic pf config allowing all traffic (matching Debian's default)
    cat > /etc/pf.conf <<-EOF
	set skip on lo
	pass in all
	pass out all
	EOF
    # EOF above must be indented with 1 tab character
    _at_boot enable pf true
    # Individual configs for specific services will go here
    mkdir -p /etc/pf
)

_system_pre_install() {
    
    # at >> /root/.bash_profile
    _package install screen
}

_system_install_debian() {
    _package install build-essential
    _package install apt-utils
    _package install make
    _package install sed
    _package install cron
    _package install vim
    _package install tzdata
    _package install net-tools # provides netstat
    _package install netcat # provides nc
    _package install python3-gi # fix "Unable to monitor PrepareForShutdown() signal"
}

_system_install() {
    # Clean up to get a minimal install
    _package purge exim4
    _package purge nginx
    _package purge apache2
    _package purge proftpd
    _package purge exim4
    _package purge postfix
    _package purge postgrey
    _package purge sendmail
    _package purge dovecot
    _package purge mariadb
    _package purge mysql
    # Install system tools
    _package install sudo
    _package install coreutils
    _package install curl
    _package install wget
    _package install easy-rsa
    _package install logrotate
    _package install whois
    _package install git
    _package install unzip
    # Tools used to run backups
    _package install rsync
    _package install rsnapshot
    # Ensure .ssh folder with authorized_keys exists
    if [ ! -d "${HOME}/.ssh" ]; then
        mkdir -p "${HOME}/.ssh"
        chmod 700 "${HOME}/.ssh"
    fi
    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        touch "${HOME}/.ssh/authorized_keys"
        chmod 600 "${HOME}/.ssh/authorized_keys"
    fi
    # Create root SSH key if needed
    if [ ! -f "${HOME}/.ssh/id_rsa" ]; then
        ssh-keygen -b 8192 -t rsa -q -f "${HOME}/.ssh/id_rsa" -N "" -C "$(whoami)@${server_ip}"
    fi
    # Configuring SSH
    _config '/etc/ssh/sshd_config' '#' ' ' <<-EOF
	Port ${ssh_port}        # Update the SSH port
	#AcceptEnv               # Stop accepting client environment variables
	LogLevel VERBOSE         # help.ubuntu.com/community/SSH/OpenSSH/Configuring
	PermitEmptyPasswords no  # Disable empty passwords
	X11Forwarding no         # Disable X11Forwarding
	MaxAuthTries 4           # superuser.com/a/1180018
	# infosec-handbook.eu/blog/wss1-basic-hardening/#s3
	KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
	Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
	MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
	HostKeyAlgorithms ssh-ed25519,rsa-sha2-256,rsa-sha2-512,ssh-rsa-cert-v01@openssh.com
	EOF
    # EOF above must be indented with 1 tab character
    if [ -n "$ssh_user" ]; then
        _config '/etc/ssh/sshd_config' '#' ' ' <<-EOF
		PermitRootLogin no     # Disable root login
		AllowUsers ${ssh_user} # Whitelist the non-SSH user
		EOF
        # EOF above must be indented with 2 tab characters
        _dir_home="/home/${ssh_user}"
        # Create $ssh_user inside superuser group
        $(_ useradd) "$ssh_user" -s /bin/sh -md "$_dir_home" -g "$(_ sudo_group)"
        # Ensure .ssh folder with authorized_keys exists
        if [ ! -d "${_dir_home}/.ssh" ]; then
            mkdir -p "${_dir_home}/.ssh"
            chmod 700 "${_dir_home}/.ssh"
        fi
        if [ ! -f "${_dir_home}/.ssh/authorized_keys" ]; then
            touch "${_dir_home}/.ssh/authorized_keys"
            chmod 600 "${_dir_home}/.ssh/authorized_keys"
        fi
        # Create SSH keys for $ssh_user
        if [ ! -f "${_dir_home}/.ssh/id_rsa" ]; then
            ssh-keygen -b 8192 -t rsa -q -f "${_dir_home}/.ssh/id_rsa" -N "" -C "${ssh_user}@${server_ip}"
        fi
        # Ensure correct ownership
        chown -R "$ssh_user" "${_dir_home}/.ssh"
        # Make $ssh_user a sudoer
        echo "${ssh_user} ALL=(ALL) NOPASSWD: ALL" | env EDITOR=tee visudo -f "$(_ local_etc)/sudoers.d/00-${ssh_user}"
    else
        _dir_home="$HOME"
    fi
    # Append public key only if not present yet
    if ! grep -qxF "$ssh_pubkey" "${_dir_home}/.ssh/authorized_keys"; then
        printf '%s\n' "$ssh_pubkey" >> "${_dir_home}/.ssh/authorized_keys"
    fi
    # Generate all missing SSH host keys (RSA, ECDSA, ED25519, etc.)
    # Used to ensure proper SSH host identity on first boot or after system provisioning.
    ssh-keygen -A
}

_system_post_install() {
    # Clean up
    _package autoremove
}
