# About

This is a Bash script that automates the process of building and installing the latest version of Emacs from source on `Ubuntu 22` or `Ubuntu 24` with either `Wayland` or `X11` display servers.

The script can be customized to execute or skip specific steps, use a custom installation directory, or include additional configuration options.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->

**Table of Contents**

> - [About](#about)
>   - [Requirements](#requirements)
>   - [Steps Performed by the Script](#steps-performed-by-the-script)
>     - [Run All Steps in Non-Interactive Mode (Default)](#run-all-steps-in-non-interactive-mode-default)
>     - [Dry-Run Mode](#dry-run-mode)
>     - [Run All Steps in Interactive Mode](#run-all-steps-in-interactive-mode)
>     - [Execute Specific Steps](#execute-specific-steps)
>     - [Skip Certain Steps](#skip-certain-steps)
>     - [Use a Custom Installation Directory](#use-a-custom-installation-directory)
>     - [Add or Override Configuration Options](#add-or-override-configuration-options)
>     - [Display Help](#display-help)
>   - [List of packages that will be installed](#list-of-packages-that-will-be-installed)
>   - [Disclaimer](#disclaimer)

<!-- markdown-toc end -->

## Requirements

- **Bash**: Required to run the script.
- **Git**: The Emacs source is cloned from a remote Git repository.
- **Sudo Privileges**: Many operations, such as installing packages and configuring system files, require elevated permissions.

---

## Steps Performed by the Script

> [!TIP]
> By default, the script executes all installation steps **non-interactively** in sequence. If you prefer to confirm each step manually, you can opt into **interactive mode** with the `-i` flag.

Here are the steps the script performs sequentially:

1. `install_deps`: Installs all the required [system packages](#list-of-packages-that-will-be-installed) (e.g., build tools and libraries).
2. `kill_emacs`: Ensures that no running Emacs process is active.
3. `remove_emacs`: Cleans up any previous Emacs installation (if applicable).
4. `pull_emacs`: Clones or updates the Emacs source repository to the latest version.
5. `build_emacs`: Configures and builds Emacs using the specified options.
6. `install_emacs`: Installs Emacs to the system (e.g., `/usr/local`).
7. `fix_emacs_xwidgets`: Fixes known [issue](https://git.savannah.gnu.org/cgit/emacs.git/tree/etc/PROBLEMS?h=master#n181) with XWidgets.
8. `copy_emacs_icon`: Replaces the default Emacs icon with a new icon (the [Spacemacs logo](https://github.com/nashamri/spacemacs-logo)).

### Run All Steps in Non-Interactive Mode (Default)

By default, the script runs **all steps non-interactively**. You can simply execute it without any options:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/KarimAziev/build-emacs/main/build-emacs.sh)"
```

Or, if you've downloaded the script locally:

```bash
./build-emacs.sh
```

> [!IMPORTANT]
> This mode assumes "yes" to all prompts and ensures a fully automated installation.

---

### Dry-Run Mode

When you run the script with the `-d` flag, it enters dry-run mode. In this mode, instead of actually executing commands, the script merely prints what it would do. This can be useful for verifying the installation process before making any changes to your system.

For example:

```bash
./build-emacs.sh -d
```

In dry-run mode, you'll see messages like:

```
[INFO] Dry-run: sudo make install
```

This mode does not require elevated privileges and won't refresh your sudo credentials, as it only simulates the actions.

### Run All Steps in Interactive Mode

If you prefer to review and confirm each step before it is executed, use the `-i` flag to enable **interactive mode**:

```bash
./build-emacs.sh -i
```

Or, if you haven't downloaded the script locally:

```bash
wget -qO- https://raw.githubusercontent.com/KarimAziev/build-emacs/main/build-emacs.sh | bash -s -- -i
```

In this mode, you will be prompted for confirmation before each step. For example:

```
Execute install_deps? [Y/n]
```

---

### Execute Specific Steps

Use the `-s` flag to specify exact steps you want to execute, separated by commas (`,`). For example, to only clone the Emacs repository, build it, and install it:

```bash
wget -qO- https://raw.githubusercontent.com/KarimAziev/build-emacs/main/build-emacs.sh | bash -s -- -s pull_emacs,build_emacs,install_emacs
```

Or, if you've downloaded the script locally:

```bash
./build-emacs.sh -s pull_emacs,build_emacs,install_emacs
```

---

### Skip Certain Steps

The `-n` flag lets you omit specific steps. For instance, to skip installing dependencies (`install_deps`) and pulling the Emacs source (`pull_emacs`):

```bash
./build-emacs.sh -n install_deps,pull_emacs
```

Or, if you haven't downloaded the script locally:

```bash
wget -qO- https://raw.githubusercontent.com/KarimAziev/build-emacs/main/build-emacs.sh | bash -s -- -n install_deps,pull_emacs
```

This will run all steps except `install_deps` and `pull_emacs`.

---

### Use a Custom Installation Directory

To specify a directory where Emacs should be cloned and built, use the `-p` flag followed by the path:

```bash
wget -qO- https://raw.githubusercontent.com/KarimAziev/build-emacs/main/build-emacs.sh | bash -s -- -p $HOME/myemacs
```

Or, if you've downloaded the script locally:

```bash
./build-emacs.sh -p $HOME/myemacs
```

The default directory is `$HOME/emacs`.

---

### Add or Override Configuration Options

The script uses the following default build options:

- `--with-pgtk`
- `--with-native-compilation=aot`
- `--without-compress-install`
- `--with-tree-sitter`
- `--with-mailutils`

If `libwebkit2gtk-4.1` is installed and meets the required version, the `--with-xwidgets` option will be added automatically.

You can append to or override these options using the `-c` flag. For example:

```bash
./build-emacs.sh -c --with-native-compilation=no,--without-pgtk,--with-my-custom-option
```

In this example, native compilation and PGTK are disabled, and the additional option `--with-my-custom-option` is included.

---

### Display Help

To see all available options, use the `-h` flag:

```bash
./build-emacs.sh -h
```

---

## List of packages that will be installed

| Package                        | Description                                                                    |
| ------------------------------ | ------------------------------------------------------------------------------ |
| autoconf                       | automatic configure script builder                                             |
| automake                       | Tool for generating GNU Standards-compliant Makefiles                          |
| bsd-mailx                      | simple mail user agent                                                         |
| build-essential                | Informational list of build-essential packages                                 |
| clang                          | C, C++ and Objective-C compiler (LLVM based), clang binary                     |
| dbus-x11                       | simple interprocess messaging system (X11 deps)                                |
| debhelper                      | helper programs for debian/rules                                               |
| dpkg-dev                       | Debian package development tools                                               |
| gawk                           | GNU awk, a pattern scanning and processing language                            |
| gcc                            | GNU C compiler                                                                 |
| g++-10                         | GNU C++ compiler                                                               |
| gcc-10                         | GNU C compiler                                                                 |
| gnutls-bin                     | GNU TLS library - commandline utilities                                        |
| gvfs                           | userspace virtual filesystem - GIO module                                      |
| heif-gdk-pixbuf                | ISO/IEC 23008-12:2017 HEIF file format decoder - gdk-pixbuf loader             |
| ibus-gtk3                      | Intelligent Input Bus - GTK3 support                                           |
| imagemagick                    | image manipulation programs – binaries                                         |
| libacl1-dev                    | access control list - static libraries and headers                             |
| libasound2                     | shared library for ALSA applications                                           |
| libasound2-dev                 | shared library for ALSA applications – development files                       |
| libaspell15                    | GNU Aspell spell-checker runtime library                                       |
| libasyncns0                    | Asynchronous name service query library                                        |
| libatk1.0-0                    | ATK accessibility toolkit                                                      |
| libatk-bridge2.0-0             | AT-SPI 2 toolkit bridge - shared library                                       |
| libatspi2.0-0                  | Assistive Technology Service Provider Interface - shared library               |
| libbrotli1                     | library implementing brotli encoder and decoder (shared libraries)             |
| libc6                          | GNU C Library: Shared libraries                                                |
| libc6-dev                      | GNU C Library: Development Libraries and Header Files                          |
| libcairo2                      | Cairo 2D vector graphics library                                               |
| libcairo-gobject2              | Cairo 2D vector graphics library (GObject library)                             |
| libcanberra0                   | simple abstract interface for playing event sounds                             |
| libcanberra-gtk3-0             | GTK+ 3.0 helper for playing widget event sounds with libcanberra               |
| libcanberra-gtk3-module        | translates GTK3 widgets signals to event sounds                                |
| libclang-dev                   | clang library - Development package                                            |
| libstdc++6                     | a shared library that is part of the GNU Standard C++ Library                  |
| libconfig-dev                  | parsing/manipulation of structured config files (development)                  |
| libdatrie1                     | Double-array trie library                                                      |
| libdb5.3                       | Berkeley v5.3 Database Libraries \[runtime\]                                   |
| libdbus-1-dev                  | simple interprocess messaging system (development headers)                     |
| libdrm2                        | Userspace interface to kernel DRM services – runtime                           |
| libegl1                        | Vendor neutral GL dispatch library – EGL support                               |
| libepoxy0                      | OpenGL function pointer management library                                     |
| libflac8                       | Free Lossless Audio Codec - runtime C library                                  |
| libfontconfig1                 | generic font configuration library - runtime                                   |
| libfreetype6                   | FreeType 2 font engine, shared library files                                   |
| libgbm1                        | generic buffer management API – runtime                                        |
| libgccjit0                     | GCC just-in-time compilation (shared library)                                  |
| libgccjit-10-dev               | GCC just-in-time compilation (development files)                               |
| libgccjit-11-dev               | GCC just-in-time compilation (development files)                               |
| libgccjit-12-dev               | GCC just-in-time compilation (development files)                               |
| libgcc-s1                      | GCC support library                                                            |
| libgdk-pixbuf2.0-0             | GDK Pixbuf library (transitional package)                                      |
| libgif7                        | library for GIF images (library)                                               |
| libgif-dev                     | library for GIF images (development)                                           |
| libgl1                         | Vendor neutral GL dispatch library – legacy GL support                         |
| libglvnd0                      | Vendor neutral GL dispatch library                                             |
| libglx0                        | Vendor neutral GL dispatch library – GLX support                               |
| libgnutls28-dev                | GNU TLS library - development files                                            |
| libgpm2                        | General Purpose Mouse - shared library                                         |
| libgpm-dev                     | General Purpose Mouse - development files                                      |
| libgraphite2-3                 | Font rendering engine for Complex Scripts – library                            |
| libgstreamer1.0-0              | Core GStreamer libraries and elements                                          |
| libgstreamer-gl1.0-0           | GStreamer GL libraries                                                         |
| libgstreamer-plugins-base1.0-0 | GStreamer libraries from the "base" set                                        |
| libgtk-3-0                     | GTK graphical user interface library                                           |
| libgtk-3-dev                   | development files for the GTK library                                          |
| libgudev-1.0-0                 | GObject-based wrapper library for libudev                                      |
| libharfbuzz0b                  | OpenType text shaping engine (shared library)                                  |
| libharfbuzz-dev                | Development files for OpenType text shaping engine                             |
| libharfbuzz-icu0               | OpenType text shaping engine ICU backend                                       |
| libhyphen0                     | ALTLinux hyphenation library - shared library                                  |
| libibus-1.0-5                  | Intelligent Input Bus - shared library                                         |
| libice6                        | X11 Inter-Client Exchange library                                              |
| libjbig0                       | JBIGkit libraries                                                              |
| libjpeg-dev                    | Independent JPEG Group's JPEG runtime library (dependency package)             |
| libjpeg-turbo8                 | IJG JPEG compliant runtime library.                                            |
| liblcms2-2                     | Little CMS 2 color management library                                          |
| liblcms2-dev                   | Little CMS 2 color management library development headers                      |
| liblockfile1                   | NFS-safe locking library                                                       |
| liblockfile-dev                | Development library for liblockfile                                            |
| libltdl7                       | System independent dlopen wrapper for GNU libtool                              |
| libm17n-0                      | multilingual text processing library - runtime                                 |
| libm17n-dev                    | multilingual text processing library - development                             |
| libmagickwand-dev              | image manipulation library – dummy package                                     |
| libmpc3                        | multiple precision complex floating-point library                              |
| libmpfr6                       | multiple precision floating-point computation                                  |
| libncurses5-dev                | transitional package for libncurses-dev                                        |
| libncurses-dev                 | developer's libraries for ncurses                                              |
| libnotify4                     | sends desktop notifications to a notification daemon                           |
| libnss-mdns                    | NSS module for Multicast DNS name resolution                                   |
| libnss-myhostname              | nss module providing fallback resolution for the current hostname              |
| libnss-systemd                 | nss module providing dynamic user and group name resolution                    |
| libogg0                        | Ogg bitstream library                                                          |
| liborc-0.4-0                   | Library of Optimized Inner Loops Runtime Compiler                              |
| liboss4-salsa2                 | OSS to Alsa compatibility library                                              |
| libotf-dev                     | Library for handling OpenType Font - development                               |
| libpango-1.0-0                 | Layout and rendering of internationalized text                                 |
| libpangocairo-1.0-0            | Layout and rendering of internationalized text                                 |
| libpangoft2-1.0-0              | Layout and rendering of internationalized text                                 |
| libpixman-1-0                  | pixel-manipulation library for X and cairo                                     |
| libpng16-16                    | PNG library - runtime (version 1.6)                                            |
| libpng-dev                     | PNG library - development (version 1.6)                                        |
| libpulse0                      | PulseAudio client libraries                                                    |
| librsvg2-2                     | SAX-based renderer library for SVG files (runtime)                             |
| librsvg2-dev                   | SAX-based renderer library for SVG files (development)                         |
| libsasl2-2                     | Cyrus SASL - authentication abstraction library                                |
| libsecret-1-0                  | Secret store                                                                   |
| libselinux1-dev                | SELinux development headers                                                    |
| libsm6                         | X11 Session Management library                                                 |
| libsndfile1                    | Library for reading/writing audio files                                        |
| libsoup2.4-1                   | HTTP library implementation in C – Shared library                              |
| libsystemd-dev                 | systemd utility library - development files                                    |
| libtdb1                        | Trivial Database - shared library                                              |
| libthai0                       | Thai language support library                                                  |
| libtiff5                       | Tag Image File Format (TIFF) library                                           |
| libtiff5-dev                   | Tag Image File Format library (TIFF), development files (transitional package) |
| libtiff-dev                    | Tag Image File Format library (TIFF), development files                        |
| libtree-sitter-dev             | incremental parsing system for programming tools (development files)           |
| libvorbis0a                    | decoder library for Vorbis General Audio Compression Codec                     |
| libvorbisenc2                  | encoder library for Vorbis General Audio Compression Codec                     |
| libvorbisfile3                 | high-level API for Vorbis General Audio Compression Codec                      |
| libwayland-client0             | wayland compositor infrastructure - client library                             |
| libwayland-cursor0             | wayland compositor infrastructure - cursor library                             |
| libwayland-egl1                | wayland compositor infrastructure - EGL library                                |
| libwayland-server0             | wayland compositor infrastructure - server library                             |
| libwebpdemux2                  | Lossy compression of digital photographic images.                              |
| libwoff1                       | library for converting fonts to WOFF 2.0                                       |
| libx11-6                       | X11 client-side library                                                        |
| libx11-dev                     | X11 client-side library (development headers)                                  |
| libx11-xcb1                    | Xlib/XCB interface library                                                     |
| libxau6                        | X11 authorisation library                                                      |
| libxcb1                        | X C Binding                                                                    |
| libxcb-render0                 | X C Binding, render extension                                                  |
| libxcb-shm0                    | X C Binding, shm extension                                                     |
| libxcomposite1                 | X11 Composite extension library                                                |
| libxcursor1                    | X cursor management library                                                    |
| libxdamage1                    | X11 damaged region extension library                                           |
| libxdmcp6                      | X11 Display Manager Control Protocol library                                   |
| libxext6                       | X11 miscellaneous extension library                                            |
| libxfixes3                     | X11 miscellaneous 'fixes' extension library                                    |
| libxft-dev                     | FreeType-based font drawing library for X (development files)                  |
| libxi6                         | X11 Input extension library                                                    |
| libxinerama1                   | X11 Xinerama extension library                                                 |
| libxkbcommon0                  | library interface to the XKB compiler - shared library                         |
| libxml2                        | GNOME XML library                                                              |
| libxml2-dev                    | GNOME XML library - development files                                          |
| libxpm4                        | X11 pixmap library                                                             |
| libxpm-dev                     | X11 pixmap library (development headers)                                       |
| libxrandr2                     | X11 RandR extension library                                                    |
| libxrender1                    | X Rendering Extension client library                                           |
| libxslt1.1                     | XSLT 1.0 processing library - runtime library                                  |
| libxt-dev                      | X11 toolkit intrinsics library (development headers)                           |
| libyajl2                       | Yet Another JSON Library                                                       |
| make                           | utility for directing compilation                                              |
| procps                         | /proc file system utilities                                                    |
| quilt                          | Tool to work with series of patches                                            |
| sharutils                      | shar, unshar, uuencode, uudecode                                               |
| sqlite3                        | Command line interface for SQLite 3                                            |
| texinfo                        | Documentation system for on-line information and printed output                |
| xaw3dg-dev                     | Xaw3d widget set development package                                           |
| zlib1g-dev                     | compression library - development                                              |

---

## Disclaimer

Please review the script before running it. I take no responsibility for any adverse effects it may have on your system. Always ensure you have a backup of your important data.
