# Copilot instructions

Read the README and packaging templates. Run `bash -n` on changed shell scripts and use the repository’s existing CI checks. Do not run privileged install/build operations on the host. Never use secrets or publishing credentials; do not publish packages.

For shell changes, run `bash -n path/to/changed-script.sh`; CI parses every tracked shell script. Do not run package installation or privileged build commands on the host.
