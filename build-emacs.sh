#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

set -e
set -o pipefail

if [ "${VERBOSE}" = "true" ]; then
  set -x
fi

SKIP_PROMPT="false"
EMACS_DIRECTORY="$HOME/emacs"
EMACS_REMOTE_URL="https://git.savannah.gnu.org/git/emacs.git"
CONFIGURE_OPTIONS=""

DEFAULT_CONFIGURE_OPTIONS=(
  "--with-pgtk"
  "--with-xwidgets"
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
  fix_emacs_xwidgets
  copy_emacs_icon
)
usage() {
  echo "Usage: $0 [OPTION]..."
  echo "Install and configure Emacs using specified options."
  echo
  echo "Options:"
  echo "  -h              Display this help message and exit."
  echo "  -p  DIRECTORY   Specify the Emacs installation directory. Default is '\$HOME/emacs'."
  echo "  -u  URL         Specify the remote URL of the Emacs Git repository. Default is https://git.savannah.gnu.org/git/emacs.git."
  echo "  -y              Skip all prompts and directly proceed with the installation and configuration steps."
  echo "  -s  [install_deps,kill_emacs,remove_emacs,pull_emacs,build_emacs,install_emacs,fix_emacs_xwidgets,copy_emacs_icon]       Specify the exact steps to execute. Steps should be separated by commas. By default, all steps are enabled."
  echo "  -n  [install_deps,kill_emacs,remove_emacs,pull_emacs,build_emacs,install_emacs,fix_emacs_xwidgets,copy_emacs_icon]       Specify the steps to skip. Steps should be separated by commas."
  echo "  -c  OPTIONS     Specify additional configure options for building Emacs. Options should be separated by commas."
  echo
  echo "Examples:"
  echo "  $0 -p \$HOME/myemacs -s pull_emacs,build_emacs,install_emacs - Perform only the pull, build, and install steps."
  echo "  $0 -p \$HOME/myemacs -n install_deps,pull_emacs - Skip installing dependencies and pulling the Emacs source, using the directory \$HOME/myemacs."
  echo "  $0 -c --with-native-compilation=no,--without-pgtk - Specify additional configure options for building Emacs."
  exit 0
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
  while getopts ":hn:p:ys:u:c:" OPTION; do
    case $OPTION in
      h)
        usage
        exit 0
        ;;
      p)
        EMACS_DIRECTORY=$(readlink -f "$OPTARG")
        ;;
      y)
        SKIP_PROMPT="yes"
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
      ?)
        echo "Illegal option: -$OPTARG"
        usage
        exit 1
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
}

main() {
  parse_arguments "$@"

  process_configure_options

  sudo -v
  refresh_sudo

  for step in "${steps[@]}"; do
    if [ $SKIP_PROMPT == "yes" ]; then
      $step
    else
      read -r -p "Execute $step? [Y/n] " answer
      case ${answer:-Y} in # set default to Y
        [yY]*)
          $step
          ;;
        *)
          echo "Skipping $step" # print a message when skipping
          ;;
      esac
    fi
  done
}

copy_emacs_icon() {
  local emacs_desktop_filename="/usr/local/share/applications/emacs.desktop"
  local download_dir="$HOME/.local/share/icons/hicolor/256x256/apps"

  # Spacemacs logo by Nasser Alshammari is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
  local icon_url="https://raw.githubusercontent.com/nashamri/spacemacs-logo/master/spacemacs-logo.svg"

  if [ -f "$emacs_desktop_filename" ]; then
    echo "Loading emacs icon"
    mkdir -p "$download_dir"

    echo "Loading emacs icon"

    wget -O "$download_dir/emacs.svg" "$icon_url" \
      && sudo sed -i "s|^\(Icon=\).*|\1$download_dir/emacs.svg|" "$emacs_desktop_filename"
  fi
}

# Fixing Emacs crashes with SIGTRAP when trying to start a WebKit xwidget.
# https://git.savannah.gnu.org/cgit/emacs.git/tree/etc/PROBLEMS?h=master#n181
fix_emacs_xwidgets() {
  local filename="/usr/local/share/applications/emacs.desktop"
  if [ -f "$filename" ]; then
    # setting the environment variables SNAP, SNAP_NAME and SNAP_REVISION will
    # make WebKit use GLib to launch subprocesses instead
    sudo sed -i 's|Exec=emacs %F|Exec=env SNAP=emacs SNAP_NAME=emacs SNAP_REVISION=1 emacs %F|' $filename
  fi
}

install_deps() {
  local pkgs=(libwebkit2gtk-4.1-dev build-essential autoconf make gcc libgnutls28-dev
    libgccjit-11-dev libgccjit-12-dev libtiff5-dev libgif-dev libjpeg-dev
    libpng-dev libxpm-dev libncurses-dev texinfo libgccjit0
    libgccjit-10-dev gcc-10 g++-10 sqlite3
    libconfig-dev libgtk-3-dev gnutls-bin libacl1-dev libotf-dev libxft-dev
    libsystemd-dev libncurses5-dev libharfbuzz-dev imagemagick libmagickwand-dev
    xaw3dg-dev libx11-dev libtree-sitter-dev automake bsd-mailx dbus-x11 debhelper
    dpkg-dev libasound2-dev libdbus-1-dev libgpm-dev liblcms2-dev liblockfile-dev
    libm17n-dev liboss4-salsa2 librsvg2-dev libselinux1-dev libtiff-dev libxml2-dev
    libxt-dev procps quilt sharutils zlib1g-dev gvfs libasound2 libaspell15
    libasyncns0 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libbrotli1 libc6
    libc6-dev libcairo-gobject2 libcairo2 libcanberra-gtk3-0 libcanberra-gtk3-module
    libcanberra0 libdatrie1 libdb5.3 libdrm2 libegl1 libepoxy0 libflac8
    libfontconfig1 libfreetype6 libgbm1 libgcc-s1 libgdk-pixbuf2.0-0 libgif7 libgl1
    libglvnd0 libglx0 libgpm2 libgraphite2-3 libgstreamer-gl1.0-0
    libgstreamer-plugins-base1.0-0 libgstreamer1.0-0 libgtk-3-0 libgudev-1.0-0
    libharfbuzz-icu0 libharfbuzz0b libhyphen0 libice6 libjbig0 libjpeg-turbo8
    liblcms2-2 liblockfile1 libltdl7 libm17n-0 libmpc3 libmpfr6 libnotify4
    libnss-mdns libnss-myhostname libnss-systemd libogg0 liborc-0.4-0 libpango-1.0-0
    libpangocairo-1.0-0 libpangoft2-1.0-0 libpixman-1-0 libpng16-16 libpulse0
    librsvg2-2 libsasl2-2 libsecret-1-0 libsm6 libsndfile1 libsoup2.4-1
    libstdc++6 libtdb1 libthai0 libtiff5 libvorbis0a libvorbisenc2 libvorbisfile3
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0
    libwebpdemux2 libwoff1 libx11-6 libx11-xcb1 libxau6 libxcb-render0 libxcb-shm0
    libxcb1 heif-gdk-pixbuf libxcomposite1 libxcursor1 libxdamage1
    gawk ibus-gtk3 libibus-1.0-5 libxdmcp6 libxext6
    libxfixes3 libxi6 libxinerama1 libxkbcommon0 libxml2 libxpm4
    libxrandr2 libxrender1 libxslt1.1 libyajl2 clang libclang-dev)

  sudo apt-get install --assume-yes "${pkgs[@]}"
}

kill_emacs() {
  if pgrep emacs > /dev/null; then
    echo "Emacs is running. Killing emacs"
    pkill emacs
  else
    echo "Emacs is not running."
  fi
}

pull_emacs() {
  if [ ! -d "$EMACS_DIRECTORY" ]; then
    echo "Cloning emacs"

    git clone --depth 1 "$EMACS_REMOTE_URL" "$EMACS_DIRECTORY"
    cd "$EMACS_DIRECTORY" || exit 1

  else
    cd "$EMACS_DIRECTORY" || exit 1

    current_origin_url=$(git remote get-url origin)

    if [ "$current_origin_url" != "$EMACS_REMOTE_URL" ]; then
      echo "Updating origin to $EMACS_REMOTE_URL"
      git remote set-url origin "$EMACS_REMOTE_URL"
    fi

    echo "Pulling emacs"
    git pull origin "$(git rev-parse --abbrev-ref HEAD)"
  fi
}

remove_emacs() {
  if [ -d "$EMACS_DIRECTORY" ]; then
    cd "$EMACS_DIRECTORY" || exit 1
    echo "Uninstalling Emacs"
    sudo make uninstall
    echo "Cleaning Emacs"
    sudo make extraclean
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
      DEFAULT_CONFIGURE_OPTIONS=("${DEFAULT_CONFIGURE_OPTIONS[@]/--with-$feature}")
      # Also remove the --without- option from user options
      USER_CONFIGURE_OPTIONS_ARRAY=("${USER_CONFIGURE_OPTIONS_ARRAY[@]/$user_option}")
    elif [[ "$user_option" == --with-* ]]; then
      # Extract the feature name up to the first '=' character, if present
      feature="${user_option#--with-}"
      feature="${feature%%=*}"
      # Remove any conflicting default option (e.g., --with-native-compilation=aot)
      DEFAULT_CONFIGURE_OPTIONS=("${DEFAULT_CONFIGURE_OPTIONS[@]/--with-$feature*}")
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

  echo "Emacs will be configured with such options: ${CONFIGURE_OPTIONS_ARRAY[*]}"
}


build_emacs() {
  if [ ! -d "$EMACS_DIRECTORY" ]; then
    echo >&2 "build_emacs: Error - Directory '$EMACS_DIRECTORY' doesn't exist."
    exit 1
  else
    cd "$EMACS_DIRECTORY"
    echo "Building Emacs"
  fi

  ./autogen.sh

  echo "Emacs will be configured with such options: ${CONFIGURE_OPTIONS_ARRAY[*]}"

  ./configure \
    "${CONFIGURE_OPTIONS_ARRAY[@]}"

  make "-j$(nproc)"
}

install_emacs() {
  if [ ! -d "$EMACS_DIRECTORY" ]; then
    echo >&2 "install_emacs: Error - Directory '$EMACS_DIRECTORY' doesn't exist."
    exit 1
  else
    cd "$EMACS_DIRECTORY"
    echo "Installing Emacs"
  fi
  sudo make install
}

main "$@"
