0. Choose a name for your installer: `Example`
1. Create a directory with lowercase name and optional OS name if not cross-platform, separated with a dot: `./example` or `./example.freebsd`
2. Inside the directory, create a mandatory shell script with matching lowercase name and `.sh` extension: `./example/example.sh` or `./example.freebsd/example.sh`
3. Create an optional .env file listing configuration parameters the installer requires: `./.example.env`

The script must have the following functions defined. Each function name must begin with `_example`.

```
#!/bin/sh
#
# Installer for "Example" application

_example_install() {
    # Everything needed to install the Example application
}

_example_uninstall() { # optional
    # Everything needed to uninstall the Example application
}

_example_backup() { # optional
    # Backs up whatever data the Example application has
}
```

Configuration parameters, if any, should be listed as key-value pairs, with keys in lowercase and prefixed with installer name.

```
# Comments are allowed
example_foo=bar
example_baz=qux
```

You can have dynamic prompts with additional validation or processing for certain configuration parameters. To do that, create a function named `_{installer_name}_prompt_{parameter_name}` in `{installer_name}.sh`. For instance, if you want to prompt for an IP address and make sure it's valid before proceeding with our `Example` installer:

```
_example_prompt_ip() (
    _prompt=$1 # shorthand to prompt text
    _defaults=$2 # shorthand to default value(s)
    _help=$3 # shorthand to help text
    shift 3 # drop first 3 args
    # You can call an external program to get your public IP here if needed.
    _defaults="0.0.0.0"
    # Prompt
    _provided_ip=$(_input 'ip' "$_prompt" "$_defaults" "$_help" "$@")
    # Here you can test the value you received
    ping -c 1 "${_provided_ip}">/dev/null 2>&1
    if [ "$?" -gt "0" ]; then
        echo "${_provided_ip} is not connectable." >&2
        # Prompt again
        _example_prompt_ip "$_prompt" "$_defaults" "$_help" "$@"
    fi
    echo "$_provided_ip"
)
```
