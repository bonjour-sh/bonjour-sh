#!/bin/sh
#
# Install command implementation

_installer_path="${BONJOUR_DIR}/command/install-scripts"

_available_installers=''
# Include installers for the install command
for _installer_dir in "$_installer_path"/*; do
    # If _installer_dir is not a directory, skip it
    if [ ! -d "$_installer_dir" ]; then
        continue
    fi
    # If _installer_dir does not contain .sh with matching name, skip it
    _installer_name=$(basename "$_installer_dir")
    if [ ! -f "$_installer_dir/$_installer_name.sh" ]; then
        continue
    fi
    # Use parameter expansion with `+` modifier to avoid extra space
    # If $_available_installers is set & not null, repeat it with trailing space
    _available_installers="${_available_installers:+$_available_installers }$_installer_name"
    # Clean up
    unset -v _installer_dir _installer_name
done

_install_command() {
    _installers=$(_input 'installers' 'Choose what to install' "$_available_installers" "$@")
    # 0. Load all selected installers
    for _installer_name in $_installers; do
        # Source both general and OS-specific scripts for this installer
        if [ -f "${_installer_path}/${_installer_name}/${_installer_name}.${BONJOUR_OS}.sh" ]; then
            . "${_installer_path}/${_installer_name}/${_installer_name}.${BONJOUR_OS}.sh"
        fi
        . "${_installer_path}/${_installer_name}/${_installer_name}.sh"
    done
    # 1. (Interactive) Collect input required for all selected installers
    for _installer_name in $_installers; do
        # If installer provides .env file, get configuration variables ready
        _installer_env="${_installer_path}/${_installer_name}/.${_installer_name}.env"
        if [ -f "$_installer_env" ]; then
            while IFS='=' read -r _env_key _env_default || [ -n "$key" ]; do
                # Skip empty lines
                [ -z "$_env_key" ] && continue
                # Skip comments
                case "$_env_key" in
                    \;* | \#*) continue ;;
                esac
                # Collect value
                _func="_${_installer_name}_prompt_${_env_key}"
                if type "$_func" 2>/dev/null | grep -q 'function'; then
                    _env_value=$("$_func" "$@")
                else
                    _env_value=$(_input "$_env_key" "Provide $_env_key" "$_env_default" "$@")
                fi
                # Set the variable
                eval "${_env_key}=\${_env_value}"
                # Clean up
                unset -v _env_key _env_default _func _env_value
            done < "$_installer_env"
        fi
    done
    # 2. (Potentially-interactive) Run pre-installers
    for _installer_name in $_installers; do
        _func="_${_installer_name}_pre_install_${BONJOUR_OS}"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
        _func="_${_installer_name}_pre_install"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
    done
    # 3. (Non-interactive) Run installers
    for _installer_name in $_installers; do
        _func="_${_installer_name}_install_${BONJOUR_OS}"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
        "_${_installer_name}_install" "$@"
    done
}
