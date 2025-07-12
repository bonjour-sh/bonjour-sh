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

_pre_install_debian() (
    apt-get update
)

_install_command() (
    _installers=$(_input 'installers' 'Choose what to install' "$_available_installers" '' "$@")
    # 0.1. Load all selected installers and their default configurations (if any)
    for _installer_name in $_installers; do
        # Source both general and OS-specific scripts for this installer
        if [ -f "${_installer_path}/${_installer_name}/${_installer_name}.${BONJOUR_OS}.sh" ]; then
            . "${_installer_path}/${_installer_name}/${_installer_name}.${BONJOUR_OS}.sh"
        fi
        # Source the installer itself
        . "${_installer_path}/${_installer_name}/${_installer_name}.sh"
        # Shorthand to what would be this installer's .env path
        _installer_env="${_installer_path}/${_installer_name}/.${_installer_name}.env"
        if [ -f "$_installer_env" ]; then
            # Source the installer .env file to have default values ready
            . "$_installer_env"
        fi
    done
    # 0.2. Load system's .bonjour.env to overwrite installer defaults
    if [ -f "${HOME}/.bonjour.env" ]; then
        . "${HOME}/.bonjour.env"
    fi
    # 1. (Interactive) Collect input required for selected installers
    for _installer_name in $_installers; do
        # Shorthand to what would be current installer's .env path
        _installer_env="${_installer_path}/${_installer_name}/.${_installer_name}.env"
        # If exists, it contains prompts (with help and defaults) for current installer
        if [ -f "$_installer_env" ]; then
            # Start with empty help text, will append if needed as we loop below
            _env_help=''
            # Go through each line in .env, collecting variables and metadata
            while IFS= read -r line || [ -n "$line" ]; do
                case "$line" in
                    \#*)
                        # Standalone comment line
                        # Escape any \n to display exactly like in source file
                        line_escaped=$(printf '%s' "${line#\# }" | sed 's/\\/\\\\/g')
                        # Append to future help text
                        _env_help="${_env_help}${line_escaped}\\n"
                        ;;
                    [a-zA-Z_]*=*)
                        # Line starts with valid shell variable name
                        _env_key=$(echo "$line" | sed -n 's/^\([a-zA-Z_][a-zA-Z0-9_]*\)=.*$/\1/p')
                        # Everything after # on that line is prompt text
                        _env_prompt=$(echo "$line" | sed -n 's/.*# *\(.*\)/\1/p')
                        # If no prompt text on that line, default to 'provide X'
                        if [ -z "$_env_prompt" ]; then
                            _env_prompt="Provide ${_env_key}"
                        fi
                        # Read value from environment to suggest default answer
                        eval "_env_default=\${$_env_key}"
                        # If still empty see if default was defined for this key
                        [ -z "$_env_default" ] && eval "_env_default=\${${_env_key}_default}"
                        # Collect value from callback (if any), else call _input
                        _func="_${_installer_name}_prompt_${_env_key}"
                        if type "$_func" 2>/dev/null | grep -q 'function'; then
                            # A callback prompt function has been defined for this variable
                            _env_value=$("$_func" "$_env_prompt" "$_env_default" "$_env_help" "$@")
                        else
                            # Call _input for this variable
                            _env_value=$(_input "$_env_key" "$_env_prompt" "$_env_default" "$_env_help" "$@")
                        fi
                        # Overwrite environment variable with value we collected
                        eval "${_env_key}=\${_env_value}"
                        # Save the answer for future (re)use and reference
                        _config "${HOME}/.bonjour.env" '#' '=' "$_env_key" "'$_env_value'"
                        # Clean up
                        unset -v _env_key _env_default _func _env_value
                        _env_help='' # Reset back to empty
                        ;;
                    *) ;;
                esac
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
    _func="_pre_install_${BONJOUR_OS}" # shared pre-install for current OS
    if type "$_func" 2>/dev/null | grep -q 'function'; then
        "$_func" "$@"
    fi
    # 3. (Non-interactive) Run installers
    for _installer_name in $_installers; do
        _func="_${_installer_name}_install_${BONJOUR_OS}"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
        "_${_installer_name}_install" "$@"
    done
    # 4. (Non-interactive) Run post-installers
    for _installer_name in $_installers; do
        _func="_${_installer_name}_post_install_${BONJOUR_OS}"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
        _func="_${_installer_name}_post_install"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
    done
)
