#!/bin/sh
#
# Reusable functions

# Dictionary function, resolves os-specific value for passed key
_() (
    if [ ! -f "${BONJOUR_DIR}/.${BONJOUR_OS}.env" ]; then
        echo "Dictionary file .${BONJOUR_OS}.env not found in ${BONJOUR_DIR}" >&2
    fi
    . "${BONJOUR_DIR}/.${BONJOUR_OS}.env"
    eval "echo \$$1"
)

_input() (
    _name=$1 # shorthand to the name of requested variable
    _prompt_text=$2 # shorthand to the prompt text
    _defaults=$3 # shorthand to the default value(s)
    # Handle optional help text argument
    if [ $# -ge 4 ]; then
        _help=$4 # if 4th argument is present, use it as help text
        shift 4 # drop first 4 args so that we don't loop through them below
    else
        _help='' # received less than 4 arguments, help text is empty
        shift 3 # drop first 3 args so that we don't loop through them below
    fi
    # Determine the prompt type: text input, boolean yes/no, multiple choice
    _type='text' # assume plain text by default
    if [ "$_defaults" = true ] || [ "$_defaults" = false ]; then
        _type='boolean' # update to boolean
    fi
    # Check if $_defaults is a space-separated list of words,
    # where each word consists only of lowercase letters and digits.
    if printf '%s\n' "$_defaults" | grep -q '^[a-z0-9._-]\{1,\}\( [a-z0-9._-]\{1,\}\)\{1,\}$'; then
        _type='select' # update to multiple choice
    fi
    $BONJOUR_DEBUG && cat >&2 <<-EOF
	
	<_input>
	    _name        $_name
	    _prompt_text $_prompt_text
	    _defaults    $_defaults
	    _type        $_type
	EOF
    # EOF above must be indented with 1 tab character
    _value='' # default to empty
    # Loop through (remaining) arguments and/or flags passed to the script
    for _arg in "$@"; do
        _key=$(echo $_arg | cut -f1 -d=) # parse --KEY out of --KEY=VALUE
        if [ "$_key" != "--$_name" ]; then # skip keys that don't match
            continue
        fi
        _value="${_arg#*=}" # parse VALUE out of --KEY=VALUE
        $BONJOUR_DEBUG && cat >&2 <<-EOF
		    ----
		    $@
		    ----
		    _arg   $_arg
		    _key   $_key
		    _value $_value
		EOF
        # EOF above must be indented with 2 tab characters
        if [ -z "$_value" ]; then # this flag was provided with no value
            if [ 'boolean' = $_type ]; then
                _value=true # for booleans, consider no value as a yes
            else
                _value="$_defaults" # otherwise, use whatever is the default
                _prompt_text="" # emptying prompt makes sure it's not shown
            fi
            $BONJOUR_DEBUG && echo " -> $_value" >&2
        fi
        break
        unset -v _arg _key
    done
    # If value was not found in arguments, and prompt is configured, do prompt
    if [ -n "$_prompt_text" ] && [ -z "$_value" ]; then
        # Format defaults displayed after prompt text
        if [ 'boolean' = $_type ]; then # if expecting boolean, format as Y/N
            _prompt_defaults=$("$_defaults" && echo "Y/n" || echo "y/N")
        else # display literally
            _prompt_defaults="$_defaults"
        fi
        # Wrap in square brackets
        if [ ! -z "$_prompt_defaults" ]; then
            _prompt_defaults=" [$_prompt_defaults]"
        fi
        # Indicate when help is available
        if [ ! -z "$_help" ]; then
            _prompt_defaults="${_prompt_defaults} / (?)"
        fi
        # Finally, prompt
        printf "${_prompt_text}${_prompt_defaults}: " >&2
        read _value < /dev/tty
    fi
    # Output help text if user asked for it
    if [ "_${_value}" = "_?" ] && [ ! -z "$_help" ]; then
        printf "\n\n${_name}:\n${_help}\n" >&2
        _input "$_name" "$_prompt_text" "$_defaults" "$_help" "$@"
        return 0 # prevent debugging nested _input calls
    fi
    $BONJOUR_DEBUG && printf "    _value '$_value'" >&2
    # Assume the defaults if $_value is still empty at this point
    if [ -z "$_value" ]; then
        _value="$_defaults"
    fi
    # For boolean prompts, ensure $_value is boolean
    if [ 'boolean' = $_type ]; then
        case "$_value" in
            [Yy]) _value=true ;;
            [Nn]) _value=false ;;
        esac
    fi
    $BONJOUR_DEBUG && printf " -> '$_value'\n</_input>\n\n" >&2
    # Return the value
    echo "$_value"
    # Clean up
    unset -v _name _prompt_text _defaults _type _value _prompt_defaults _help
)

_get_public_ip() (
    _url='http://checkip.amazonaws.com/'
    if command -v curl >/dev/null 2>&1; then
        curl -s "$_url"
        exit
    fi
    if command -v fetch >/dev/null 2>&1; then
        fetch -qo - "$_url"
        exit
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -qO- "$_url"
        exit
    fi
    echo 'Error: curl, fetch, or wget not found.' >&2
    exit 1
)
