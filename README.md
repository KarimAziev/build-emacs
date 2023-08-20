# Emacs Installer Script

This is a bash script to automate the installation and configuration of Emacs on Ubuntu 22.

You can run the script with different flags to modify its behavior. The available options are:

1. `-h`: Display help and exit.
2. `-p DIRECTORY` : Specify the Emacs installation directory. By default, it is =$HOME/emacs=.
3. `-y`: Skip all the prompts and directly install Emacs and proceed with the steps.
4. `-n STEPS`: Specify the steps to skip. Steps need to be comma-separated.

## Steps

Here are the steps that this script will perform in order:

1. `install_deps`: Install the necessary dependencies for Emacs.
2. `kill_emacs`: Kill any running Emacs process.
3. `remove_emacs`: Uninstall Emacs and perform a clean up.
4. `pull_emacs`: Pull the latest Emacs source code.
5. `build_emacs`: Build Emacs from the source code.
6. `install_emacs`: Install Emacs from the built source code.
7. `fix_emacs_xwidgets`: Fix any issues related to Emacs XWidgets.
8. `copy_emacs_icon`: Copy the Emacs icon file.

## Example

To use the script to build and install Emacs in a custom directory without installing dependencies and pulling Emacs source, you can use:

```shell
./install_emacs.sh -p $HOME/myemacs -n install_deps,pull_emacs
```

## Requirements

This script requires that you have bash, git, and sudo privilege. It's designed to work on Unix-like operating systems.

## Disclaimer

Please review the script before running it. I take no responsibility for any adverse effects it may have on your system. Always ensure you have a backup of your important data.
