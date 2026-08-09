# SHlauncher
SHlauncher is a CLI minecraft launcher written entirely in bash with minimal dependencies.
It has the goal of being as light as possible (unlike electron launchers)

## Dependencies

The launcher uses as a main dependency ([jq](https://github.com/jqlang/jq)) which IS required for the launcher to function properly. But to keep the portability, a binary can provided (should be stored at ".minecraft/SHlauncher/jq/") and will be used when using the flag `--portable`

Without counting jq, the launcher also relies on tools that are usually preinstalled, like `sha1sum` `curl` `unzip` `gz` `tar` `awk` etc...
Please note that the launcher is not POSIX-compliant. It only support bash. This script wasn't tested with zsh and does not support sh, ash, dash and fish

## Features
- **Colors** : The launcher uses by default the 24 bit color system (Can be disabled or modified)

- **Multi-instances system** : The launcher support managing multiples instances/profiles

- **Modloader support** : SHlauncher supports the Neoforge modloader

- **Internal shell** : The script uses an internal shell instead of the normal bash shell. It allows the launcher to use a personalized prompt string (`PS1`), hold an history and keep an clean environment.

- **Setting system** : The launcher uses a settings-based system to store information between shutdowns with everything being accessible to the user

- **Portability** : The launcher is bundled in his own `.minecraft` folder and does not interfere with the official launcher's one. It also means that it is entirely portable.

## Planned features

This list is sorted in the order in which I would like to create them

- **More modloader support** : I want to add fabric to the launcher (forge and quilt will come afterwards)

- **Server support** : Yes, the launcher doesn't support servers yet

## License
This project is licensed under the GNU General Public License Version 3.0
