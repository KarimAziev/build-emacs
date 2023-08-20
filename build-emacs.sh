#!/usr/bin/env bash

set -e
set -o pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_PROMPT="false"
EMACS_DIRECTORY="$HOME/emacs"

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
  echo "Install and configure emacs with the specified options."
  echo
  echo "Options:"
  echo "  -h              display this help and exit"
  echo "  -p  DIRECTORY   specify the emacs directory, default is '\$HOME/emacs'"
  echo "  -y              skip all the prompts and directly install emacs and proceed with the steps"
  echo "  -n  STEPS       specify the steps to skip, steps have to be comma separated [install_deps,kill_emacs,remove_emacs,pull_emacs,build_emacs,install_emacs,fix_emacs_xwidgets,copy_emacs_icon]"
  echo
  echo "Example:"
  echo "  $0 -p \$HOME/myemacs -n install_deps,pull_emacs build and install emacs in \$HOME/myemacs without installing dependencies and pulling emacs source."
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

parse_arguments() {
  while getopts ":hn:p:y" OPTION; do
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
      ?)
        echo "Illegal option: -$OPTARG"
        usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))
}

main() {
  parse_arguments "$@"

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
  local filename="/usr/local/share/applications/emacs.desktop"
  local replace="Icon=$DOTFILES_ROOT/icons/emacs.png"
  local search
  if [ -f "$DOTFILES_ROOT/icons/emacs.png" ]; then
    search=$(grep Icon=emacs "$filename")
    if grep Icon=emacs "$filename"; then
      sudo sed -i "s|$search|$replace|" "$filename"
    fi
  fi
}

fix_emacs_xwidgets() {
  local filename="/usr/local/share/applications/emacs.desktop"
  sudo sed -i 's|Exec=emacs %F|Exec=env SNAP=emacs SNAP_NAME=emacs SNAP_REVISION=1 emacs %F|' $filename
}

install_deps() {
  local pkgs=(libwebkit2gtk-4.1-dev build-essential autoconf make gcc libgnutls28-dev libgccjit-12-dev
    libtiff5-dev libgif-dev libjpeg-dev libpng-dev libxpm-dev libncurses-dev texinfo
    libjansson4 libjansson-dev libgccjit0 libgccjit-10-dev gcc-10 g++-10 sqlite3
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
    librsvg2-2 libsasl2-2 libsecret-1-0 libsm6 libsndfile1 libsoup2.4-1 libssl1.1
    libstdc++6 libtdb1 libthai0 libtiff5 libvorbis0a libvorbisenc2 libvorbisfile3
    libwayland-client0 libwayland-cursor0 libwayland-egl1 libwayland-server0
    libwebpdemux2 libwoff1 libx11-6 libx11-xcb1 libxau6 libxcb-render0 libxcb-shm0
    libxcb1 heif-gdk-pixbuf libxcomposite1 libxcursor1 libxdamage1
    libwebkit2gtk-4.1-dev gawk ibus-gtk3 libibus-1.0-5 libxdmcp6 libxext6
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
    git clone --depth 1 https://git.savannah.gnu.org/git/emacs.git "$EMACS_DIRECTORY"
    cd "$EMACS_DIRECTORY" || exit 1
  else
    cd "$EMACS_DIRECTORY" || exit 1
    echo "Pulling emacs"
    git pull origin "$(git rev-parse --abbrev-ref HEAD)"
  fi
}

remove_emacs() {
  cd "$EMACS_DIRECTORY" || exit 1
  echo "Uninstalling Emacs"
  sudo make uninstall
  echo "Cleaning Emacs"
  sudo make extraclean
}

build_emacs() {
  cd "$EMACS_DIRECTORY" || exit 1

  ./autogen.sh
  ./configure \
    --with-dbus \
    --with-pgtk \
    --with-xwidgets \
    --with-native-compilation=aot \
    --with-modules \
    --with-mailutils \
    --with-json \
    --without-compress-install \
    --with-tree-sitter \
    --with-gif \
    --with-png \
    --with-tiff \
    --with-xpm \
    --with-xft \
    --with-xml2 \
    --with-jpeg \
    --with-x-toolkit=gtk3 \
    --with-harfbuzz

  make "-j$(nproc)"
}

install_emacs() {
  cd "$EMACS_DIRECTORY" || exit 1
  sudo make install
}

main "$@"
