#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

set -e
set -o pipefail

log_info() {
  printf "\033[32m[INFO]\033[0m %s\n" "$1"
}

log_error() {
  printf "\033[31m[ERROR]\033[0m %s\n" "$1" >&2
}

log_warn() {
  echo -e "\033[1;33m[WARNING]\033[0m $1" >&2
}

if [ "${VERBOSE}" = "true" ]; then
  set -x
fi

DRY_RUN=${DRY_RUN:-false}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run: $*"
  else
    log_info "Executing: $*"
    "$@"
  fi
}

SKIP_PROMPT=${SKIP_PROMPT:-yes}
EMACS_DIRECTORY="$HOME/emacs"
DEFAULT_EMACS_REMOTE_URL="https://git.savannah.gnu.org/git/emacs.git"
GITHUB_EMACS_REMOTE_URL="https://github.com/emacs-mirror/emacs.git"
EMACS_REMOTE_URL="$DEFAULT_EMACS_REMOTE_URL"
EMACS_REF=""
CONFIGURE_OPTIONS=""

WEBKIT_REQUIRED=2.12
WEBKIT_BROKEN=2.41.92

# Fetch the installed version of libwebkit2gtk-4.1
WEBKIT_VERSION=$(dpkg-query -W -f='${Version}\n' libwebkit2gtk-4.1-0 2> /dev/null | cut -d '-' -f1 || true)

version_ge() {
  dpkg --compare-versions "$1" ge "$2"
}

version_lt() {
  dpkg --compare-versions "$1" lt "$2"
}

DEFAULT_CONFIGURE_OPTIONS=(
  "--with-pgtk"
  "--with-native-compilation=aot"
  "--without-compress-install"
  "--with-tree-sitter"
  "--with-mailutils"
)

steps=(
  install_deps
  kill_emacs
  remove_emacs
  pull_emacs
  build_emacs
  install_emacs
  copy_emacs_icon
)

check_webkit_version() {
  if version_ge "$WEBKIT_VERSION" "$WEBKIT_REQUIRED" && version_lt "$WEBKIT_VERSION" "$WEBKIT_BROKEN"; then
    DEFAULT_CONFIGURE_OPTIONS+=("--with-xwidgets")
    steps+=(fix_emacs_xwidgets)
  else
    if [[ -z "$WEBKIT_VERSION" ]]; then
      log_warn "Xwidgets are not available. libwebkit2gtk-4.1-0 version $WEBKIT_REQUIRED or higher, but lower than $WEBKIT_BROKEN, is required."
    else
      log_warn "Xwidgets are not available. Detected libwebkit2gtk-4.1-0 version is $WEBKIT_VERSION. Version $WEBKIT_REQUIRED or higher but lower than $WEBKIT_BROKEN is required."
    fi
  fi
}

check_webkit_version

usage() {
  echo "Usage: $0 [OPTION]..."
  echo "Install and configure Emacs using specified options."
  echo
  echo "Options:"
  echo "  -h              Display this help message and exit."
  echo "  -i              Run in interactive mode, prompting for confirmation at each step."
  echo "  -y              Run in non-interactive mode (default) and execute all steps without prompting."
  echo "  -p  DIRECTORY   Specify the Emacs installation directory. Default is '\$HOME/emacs'."
  echo "  -d              Run in dry-run mode: instead of executing commands, the script will print what it would do."
  echo "  -g              Use the GitHub Emacs mirror: https://github.com/emacs-mirror/emacs.git."
  echo "  -u  URL         Specify the remote URL of the Emacs Git repository."
  echo "                  Default is https://git.savannah.gnu.org/git/emacs.git."
  echo "  -r  REF         Build a specific Git branch, tag, or commit."
  echo "  -s  STEPS       Specify the exact steps to execute. Steps should be separated by commas."
  echo "                  Available steps: install_deps, kill_emacs, remove_emacs, pull_emacs,"
  echo "                  build_emacs, install_emacs, fix_emacs_xwidgets, copy_emacs_icon."
  echo "  -n  STEPS       Specify the steps to skip. Steps should be separated by commas."
  echo "                  Available steps: install_deps, kill_emacs, remove_emacs, pull_emacs,"
  echo "                  build_emacs, install_emacs, fix_emacs_xwidgets, copy_emacs_icon."
  echo "                  By default, all steps are enabled."
  echo "  -c  OPTIONS     Specify additional configure options for building Emacs. Options should be separated by commas."
  echo
  echo "Examples:"
  echo "  $0                              Run all steps in non-interactive mode (default)."
  echo "  $0 -i                           Run all steps in interactive mode, prompting for confirmation at each step."
  echo "  $0 -y                           Explicitly run all steps in non-interactive mode (same as default)."
  echo "  $0 -p \$HOME/myemacs -s pull_emacs,build_emacs,install_emacs"
  echo "                                  Perform only the pull, build, and install steps in non-interactive mode."
  echo "  $0 -p \$HOME/myemacs -n install_deps,pull_emacs"
  echo "                                  Skip installing dependencies and pulling the Emacs source."
  echo "  $0 -g -r emacs-30.1"
  echo "                                  Build the emacs-30.1 tag from the GitHub mirror."
  echo "  $0 -r feature/native-comp"
  echo "                                  Build a branch from the default Savannah remote."
  echo "  $0 -p \$HOME/src/emacs -s build_emacs,install_emacs"
  echo "                                  Build and install the revision already checked out in an existing Emacs source directory."
  echo "  $0 -c --with-native-compilation=no,--without-pgtk"
  echo "                                  Specify additional configure options for building Emacs."
  exit "${1:-0}"
}

filter_steps() {
  # We keep the original IFS value in oldIFS, set IFS to
  # ',' for our purposes and then set IFS back to its original value using oldIFS
  #  after we're done using it
  local oldIFS="$IFS"
  IFS=','
  read -r -a skipsteps <<< "$1"
  IFS="$oldIFS"
  local filtered_steps=()
  for step in "${steps[@]}"; do
    if ! printf '%s\n' "${skipsteps[@]}" | grep -q -P "^$step$"; then
      filtered_steps+=("$step")
    fi
  done
  steps=("${filtered_steps[@]}")
}

set_steps() {
  local oldIFS="$IFS"
  IFS=','
  read -r -a steps <<< "$1"
  IFS="$oldIFS"
}

parse_arguments() {
  mode="default"
  while getopts ":dghin:p:r:ys:u:c:" OPTION; do
    case $OPTION in
      d)
        DRY_RUN=true
        ;;

      h)
        usage
        ;;
      g)
        EMACS_REMOTE_URL="$GITHUB_EMACS_REMOTE_URL"
        ;;
      i)
        if [ "$mode" = "non-interactive" ]; then
          log_error >&2 "Error: Cannot use -i (interactive) and -y (non-interactive) together."
          exit 1
        fi
        mode="interactive"
        SKIP_PROMPT="no"
        ;;
      y)
        if [ "$mode" = "interactive" ]; then
          log_error >&2 "Error: Cannot use -i (interactive) and -y (non-interactive) together."
          exit 1
        fi
        mode="non-interactive"
        SKIP_PROMPT="yes"
        ;;
      p)
        EMACS_DIRECTORY=$(readlink -f "$OPTARG")
        ;;
      r)
        EMACS_REF="$OPTARG"
        ;;
      n)
        filter_steps "$OPTARG"
        ;;
      s)
        set_steps "$OPTARG"
        ;;
      u)
        EMACS_REMOTE_URL="$OPTARG"
        ;;
      c)
        CONFIGURE_OPTIONS="$OPTARG"
        ;;
      \?)
        log_error "Illegal option: -$OPTARG"
        usage 1
        ;;
      :)
        log_error "Option -$OPTARG requires an argument."
        usage 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
}

refresh_sudo() {
  while true; do
    sudo -v
    sleep 60
  done &
  SUDO_REFRESH_PID=$! # Capture PID of the background process

  if ! kill -s 0 "$SUDO_REFRESH_PID" 2> /dev/null; then
    log_error >&2 "Error: Failed to start refresh_sudo background process."
    exit 1
  fi
}

cleanup() {
  kill "$SUDO_REFRESH_PID" 2> /dev/null
}

main() {
  parse_arguments "$@"
  if [ "$DRY_RUN" = true ]; then
    log_info "Running in dry-run mode. No commands will be executed."
  else
    log_info "Running in $([ "$SKIP_PROMPT" = "yes" ] && echo 'non-interactive' || echo 'interactive') mode."
  fi

  log_info "Steps to execute: ${steps[*]}"

  process_configure_options

  run_cmd sudo -v # Update the user's cached credentials

  run_cmd refresh_sudo

  run_cmd trap cleanup EXIT

  for step in "${steps[@]}"; do
    if [ "$SKIP_PROMPT" = "no" ]; then
      read -r -p "Execute $step? [Y/n] " answer
      case ${answer:-Y} in
        [yY]*) $step ;;
        *) log_info "Skipping $step" ;;
      esac
    else
      $step
    fi
  done
}

copy_emacs_icon() {
  local emacs_desktop_filename="/usr/local/share/applications/emacs.desktop"
  local download_dir="$HOME/.local/share/icons/hicolor/256x256/apps"

  # Spacemacs logo by Nasser Alshammari is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
  local icon_url="https://raw.githubusercontent.com/nashamri/spacemacs-logo/master/spacemacs-logo.svg"

  if [ -f "$emacs_desktop_filename" ]; then
    log_info "Loading emacs icon"
    run_cmd mkdir -p "$download_dir"

    run_cmd wget -O "$download_dir/emacs.svg" "$icon_url" \
      && run_cmd sudo sed -i "s|^\(Icon=\).*|\1$download_dir/emacs.svg|" "$emacs_desktop_filename"
  fi
}

# Fixing Emacs crashes with SIGTRAP when trying to start a WebKit xwidget.
# https://git.savannah.gnu.org/cgit/emacs.git/tree/etc/PROBLEMS?h=master#n181
fix_emacs_xwidgets() {
  local filename="/usr/local/share/applications/emacs.desktop"
  if [ -f "$filename" ]; then
    # setting the environment variables SNAP, SNAP_NAME and SNAP_REVISION will
    # make WebKit use GLib to launch subprocesses instead
    run_cmd sudo sed -i 's|Exec=emacs %F|Exec=env SNAP=emacs SNAP_NAME=emacs SNAP_REVISION=1 emacs %F|' $filename
  fi
}

detect_and_install_gccjit() {
  gcc_version=$(/usr/bin/gcc -dumpversion | cut -d. -f1)
  log_info "Detected GCC major version: $gcc_version"

  if [ "$gcc_version" -ge 14 ]; then
    log_info "Using libgccjit-14-dev for gcc version $gcc_version"
    run_cmd sudo apt-get install --assume-yes libgccjit-14-dev
  elif [ "$gcc_version" -ge 13 ]; then
    log_info "Using libgccjit-13-dev for gcc version $gcc_version"
    run_cmd sudo apt-get install --assume-yes libgccjit-13-dev
  elif [ "$gcc_version" -ge 12 ]; then
    log_info "Using libgccjit-12-dev for gcc version $gcc_version"
    run_cmd sudo apt-get install --assume-yes libgccjit-12-dev
  elif [ "$gcc_version" -ge 11 ]; then
    log_info "Using libgccjit-11-dev for gcc version $gcc_version"
    run_cmd sudo apt-get install --assume-yes libgccjit-11-dev
  elif [ "$gcc_version" -ge 10 ]; then
    log_info "Using libgccjit-10-dev for gcc version $gcc_version"
    run_cmd sudo apt-get install --assume-yes libgccjit-10-dev
  else
    log_warn "GCC version ($gcc_version) is less than 10; native-compilation might not be supported."
    run_cmd sudo apt-get install --assume-yes libgccjit-dev
  fi
}

install_deps() {
  local pkgs=(autoconf automake bsd-mailx build-essential clang dbus-x11
    debhelper dpkg-dev g++-10 gawk gcc gcc-10 gnutls-bin gvfs heif-gdk-pixbuf
    ibus-gtk3 imagemagick libacl1-dev libasound2 libasound2-dev libaspell15
    libasyncns0 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libbrotli1 libc6
    libc6-dev libcairo-gobject2 libcairo2 libcanberra-gtk3-0
    libcanberra-gtk3-module libcanberra0 libclang-dev libconfig-dev libdatrie1
    libdb5.3 libdbus-1-dev libdrm2 libegl1 libepoxy0 libflac8 libfontconfig1
    libfreetype6 libgbm1 libgcc-s1 libgccjit0 libgdk-pixbuf2.0-0 libgif-dev libgif7 libgl1
    libglvnd0 libglx0 libgnutls28-dev libgpm-dev libgpm2 libgraphite2-3
    libgstreamer-gl1.0-0 libgstreamer-plugins-base1.0-0 libgstreamer1.0-0
    libgtk-3-0 libgtk-3-dev libgudev-1.0-0 libharfbuzz-dev libharfbuzz-icu0
    libharfbuzz0b libhyphen0 libibus-1.0-5 libice6 libjbig0 libjpeg-dev
    libjpeg-turbo8 liblcms2-2 liblcms2-dev liblockfile-dev liblockfile1 libltdl7
    libm17n-0 libm17n-dev libmagickwand-dev libmpc3 libmpfr6 libncurses-dev
    libncurses5-dev libnotify4 libnss-mdns libnss-myhostname libnss-systemd
    libogg0 liborc-0.4-0 liboss4-salsa2 libotf-dev libpango-1.0-0
    libpangocairo-1.0-0 libpangoft2-1.0-0 libpixman-1-0 libpng-dev libpng16-16
    libpulse0 librsvg2-2 librsvg2-dev libsasl2-2 libsecret-1-0 libselinux1-dev
    libsm6 libsndfile1 libsoup2.4-1 libstdc++6 libsystemd-dev libtdb1 libthai0
    libtiff-dev libtiff5 libtiff5-dev libtree-sitter-dev libvorbis0a libvorbisenc2
    libvorbisfile3 libwayland-client0 libwayland-cursor0 libwayland-egl1
    libwayland-server0 libwebpdemux2 libwoff1 libx11-6 libx11-dev libx11-xcb1
    libxau6 libxcb-render0 libxcb-shm0 libxcb1 libxcomposite1 libxcursor1
    libxdamage1 libxdmcp6 libxext6 libxfixes3 libxft-dev libxi6 libxinerama1
    libxkbcommon0 libxml2 libxml2-dev libxpm-dev libxpm4 libxrandr2 libxrender1
    libxslt1.1 libxt-dev libyajl2 make procps quilt sharutils sqlite3 texinfo
    xaw3dg-dev zlib1g-dev)

  local os_release_file="/etc/os-release"
  local ubuntu_version_id=""
  local ubuntu_major_version

  if [ -f "$os_release_file" ]; then
    ubuntu_version_id=$(sed -n 's/^VERSION_ID=//p' "$os_release_file" | head -n 1)
    ubuntu_version_id="${ubuntu_version_id#\"}"
    ubuntu_version_id="${ubuntu_version_id%\"}"
    ubuntu_version_id="${ubuntu_version_id#\'}"
    ubuntu_version_id="${ubuntu_version_id%\'}"
  fi

  if [ -n "$ubuntu_version_id" ]; then
    ubuntu_major_version="${ubuntu_version_id%%.*}"
  else
    log_warn "Cannot detect Ubuntu version; proceeding with full dependency list."
    ubuntu_version_id=22
    ubuntu_major_version=22
  fi

  if [ "$ubuntu_major_version" -ge 24 ]; then
    log_info "Detected Ubuntu $ubuntu_version_id: adjusting dependencies for Ubuntu 24"
    local remove_pkgs=(libasound2 libflac8 libtiff5)
    for pkg in "${remove_pkgs[@]}"; do
      local new_pkgs=()
      for installed in "${pkgs[@]}"; do
        if [ "$installed" != "$pkg" ]; then
          new_pkgs+=("$installed")
        fi
      done
      pkgs=("${new_pkgs[@]}")
    done
  fi

  run_cmd sudo apt-get install --assume-yes "${pkgs[@]}"

  detect_and_install_gccjit
}

kill_emacs() {
  if pgrep emacs > /dev/null; then
    log_warn "Emacs is running. Killing emacs"
    run_cmd pkill emacs
  else
    log_info "Skipping killing Emacs: Emacs is not running."
  fi
}

pull_emacs() {
  local is_new_clone=false
  local current_branch=""

  if [ ! -d "$EMACS_DIRECTORY" ]; then
    log_info "Cloning emacs"

    if ! run_cmd git clone --depth 1 "$EMACS_REMOTE_URL" "$EMACS_DIRECTORY"; then
      log_error "Error: Failed to clone Emacs repository. Check the URL or network connection."
      exit 1
    fi

    cd "$EMACS_DIRECTORY" || {
      log_error >&2 "Error: The Emacs directory '$EMACS_DIRECTORY' does not exist."
      exit 1
    }

    is_new_clone=true

  else
    cd "$EMACS_DIRECTORY" || {
      log_error >&2 "Error: The Emacs directory '$EMACS_DIRECTORY' does not exist."
      exit 1
    }

    current_origin_url=$(git remote get-url origin)

    if [ "$current_origin_url" != "$EMACS_REMOTE_URL" ]; then
      log_info "Updating origin to $EMACS_REMOTE_URL"
      run_cmd git remote set-url origin "$EMACS_REMOTE_URL"

    fi

  fi

  if [ -n "$EMACS_REF" ]; then
    log_info "Fetching Emacs ref $EMACS_REF"
    if ! run_cmd git fetch --depth 1 origin "$EMACS_REF"; then
      log_error "Error: Failed to fetch Emacs ref '$EMACS_REF'. Check that the branch, tag, or commit exists."
      exit 1
    fi

    log_info "Checking out Emacs ref $EMACS_REF"
    run_cmd git checkout --detach FETCH_HEAD
  elif [ "$is_new_clone" = false ]; then
    current_branch=$(git symbolic-ref --quiet --short HEAD || true)

    if [ -n "$current_branch" ]; then
      log_info "Pulling Emacs branch $current_branch"
      run_cmd git pull --ff-only origin "$current_branch"
    else
      log_info "Updating Emacs from the remote's default branch"
      run_cmd git fetch --depth 1 origin HEAD
      run_cmd git checkout --detach FETCH_HEAD
    fi
  fi
}

remove_emacs() {
  if [ -d "$EMACS_DIRECTORY" ]; then
    cd "$EMACS_DIRECTORY" || {
      log_error >&2 "Error: The Emacs directory '$EMACS_DIRECTORY' does not exist."
      exit 1
    }
    log_info "Uninstalling Emacs"
    run_cmd sudo make uninstall
    log_info "Cleaning Emacs"
    run_cmd sudo make extraclean
  fi
}

process_configure_options() {
  local oldIFS="$IFS"
  IFS=',' read -r -a USER_CONFIGURE_OPTIONS_ARRAY <<< "$CONFIGURE_OPTIONS"
  IFS="$oldIFS"

  for user_option in "${USER_CONFIGURE_OPTIONS_ARRAY[@]}"; do
    if [[ "$user_option" == --without-* ]]; then
      # Extract the feature name (e.g., --without-pgtk -> pgtk)
      feature="${user_option#--without-}"
      # Remove the corresponding default option (e.g., --with-pgtk)
      DEFAULT_CONFIGURE_OPTIONS=("${DEFAULT_CONFIGURE_OPTIONS[@]/--with-$feature/}")
      # Also remove the --without- option from user options
      USER_CONFIGURE_OPTIONS_ARRAY=("${USER_CONFIGURE_OPTIONS_ARRAY[@]/$user_option/}")
    elif [[ "$user_option" == --with-* ]]; then
      # Extract the feature name up to the first '=' character, if present
      feature="${user_option#--with-}"
      feature="${feature%%=*}"
      # Remove any conflicting default option (e.g., --with-native-compilation=aot)
      DEFAULT_CONFIGURE_OPTIONS=("${DEFAULT_CONFIGURE_OPTIONS[@]/--with-$feature*/}")
    fi
  done

  CONFIGURE_OPTIONS_ARRAY=("${DEFAULT_CONFIGURE_OPTIONS[@]}" "${USER_CONFIGURE_OPTIONS_ARRAY[@]}")

  if [ "$XDG_SESSION_TYPE" = "xwayland" ]; then
    for option in "${CONFIGURE_OPTIONS_ARRAY[@]}"; do
      if [[ "$option" == "--with-pgtk" ]]; then
        CONFIGURE_OPTIONS_ARRAY+=("--with-x-toolkit=gtk3")
        break
      fi
    done
  fi

  log_info "Emacs will be configured with such options: ${CONFIGURE_OPTIONS_ARRAY[*]}"
}

build_emacs() {
  if [ ! -d "$EMACS_DIRECTORY" ]; then
    log_error >&2 "build_emacs: Error - Directory '$EMACS_DIRECTORY' doesn't exist."
    exit 1
  else
    cd "$EMACS_DIRECTORY"
    log_info "Running autogen.sh"
  fi

  run_cmd ./autogen.sh

  log_info "Emacs will be configured with such options: ${CONFIGURE_OPTIONS_ARRAY[*]}"

  gcc_major_version=$(gcc -dumpversion | cut -d. -f1)
  gccjit_dir="/usr/lib/gcc/x86_64-linux-gnu/${gcc_major_version}"

  if [ -d "$gccjit_dir" ]; then
    log_info "Using gcc jit directory: $gccjit_dir"
    export LIBRARY_PATH="$gccjit_dir:$LIBRARY_PATH"
    export LDFLAGS="-L$gccjit_dir $LDFLAGS"
  else
    log_warn "Directory $gccjit_dir does not exist. Proceeding without modifying LIBRARY_PATH or LDFLAGS."
  fi

  run_cmd ./configure "${CONFIGURE_OPTIONS_ARRAY[@]}"

  log_info "Building Emacs"
  run_cmd make "-j$(nproc)"
}

install_emacs() {
  if [ ! -d "$EMACS_DIRECTORY" ]; then
    log_error >&2 "install_emacs: Error - Directory '$EMACS_DIRECTORY' doesn't exist."
    exit 1
  else
    cd "$EMACS_DIRECTORY"
    log_info "Installing Emacs"
  fi
  run_cmd sudo make install
}

main "$@"
