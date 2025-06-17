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

_install_command() (
    _installers=$(_input 'installers' 'Choose what to install' "$_available_installers" "$@")
    # 0. Load all selected installers and their default configurations (if any)
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
                        # Standalone comment line, append to future help text
                        _env_help="${_env_help}${line#\# }\\n"
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
                        # Collect value from callback (if any), else call _input
                        _func="_${_installer_name}_prompt_${_env_key}"
                        if type "$_func" 2>/dev/null | grep -q 'function'; then
                            # A callback prompt function has been defined for this variable
                            _env_value=$("$_func" "$@")
                        else
                            # Call _input for this variable
                            _env_value=$(_input "$_env_key" "$_env_prompt" "$_env_default" "$_env_help" "$@")
                        fi
                        # Overwrite environment variable with value we collected
                        eval "${_env_key}=\${_env_value}"
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
    # 3. (Non-interactive) Run installers
    for _installer_name in $_installers; do
        _func="_${_installer_name}_install_${BONJOUR_OS}"
        if type "$_func" 2>/dev/null | grep -q 'function'; then
            "$_func" "$@"
        fi
        "_${_installer_name}_install" "$@"
    done
)
