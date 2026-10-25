dnl lightningcss-php extension configuration.
dnl
dnl A plain `phpize && ./configure && make` — the path PIE and PECL run — never
dnl invokes cargo, so this file drives the Rust shim build itself: it checks
dnl the toolchain here (where build-environment checks belong), records the
dnl cargo rules that land in `Makefile.objects`, and links the resulting static
dnl archive into lightningcss.so.
dnl Copyright 2026 Fojle Rabbi (Rabib)
dnl SPDX-License-Identifier: Apache-2.0

PHP_ARG_ENABLE([lightningcss],
  [whether to enable the lightningcss extension],
  [AS_HELP_STRING([--enable-lightningcss],
    [Enable lightningcss (CSS processing on a vendored Lightning CSS core)])],
  [no])

if test "$PHP_LIGHTNINGCSS" != "no"; then

  dnl Toolchain check. The scaffold shim is edition 2021 (MSRV 1.75); the
  dnl engine dependency raises this floor when it lands, and this check is
  dnl bumped with it. rustup installs to ~/.cargo/bin, which is not always
  dnl ahead of a distro cargo on PATH, so an MSRV-failing PATH cargo falls
  dnl back to that location before giving up.
  AC_CHECK_PROG([LIGHTNINGCSS_CARGO], [cargo], [cargo], [no])
  if test "$LIGHTNINGCSS_CARGO" = "no"; then
    AC_MSG_ERROR([cargo not found. lightningcss builds its shim from Rust source and needs a Rust toolchain >= 1.75; install rustup and re-run configure.])
  fi

  lightningcss_cargo_ok() {
    test -n "$1" || return 1
    v=`"$1" --version 2>/dev/null | awk '{ print $2 }'`
    major=`printf '%s' "$v" | cut -d. -f1`
    minor=`printf '%s' "$v" | cut -d. -f2`
    test -n "$major" && test "$major" -ge 1 || return 1
    test "$major" -gt 1 || test "$minor" -ge 75
  }

  LIGHTNINGCSS_CARGO_VERSION=`$LIGHTNINGCSS_CARGO --version 2>/dev/null | awk '{ print $2 }'`
  if ! lightningcss_cargo_ok "$LIGHTNINGCSS_CARGO"; then
    if test -x "$HOME/.cargo/bin/cargo" && lightningcss_cargo_ok "$HOME/.cargo/bin/cargo"; then
      LIGHTNINGCSS_CARGO="$HOME/.cargo/bin/cargo"
      LIGHTNINGCSS_CARGO_VERSION=`$LIGHTNINGCSS_CARGO --version 2>/dev/null | awk '{ print $2 }'`
    else
      AC_MSG_ERROR([cargo $LIGHTNINGCSS_CARGO_VERSION is older than the shim MSRV of 1.75. Install a current toolchain with rustup and re-run configure.])
    fi
  fi
  PHP_SUBST([LIGHTNINGCSS_CARGO])

  dnl Shim headers live with the Rust bridge that will own the vendored engine.
  dnl The build driver passes LIGHTNINGCSS_SHIM_INCLUDE; the fallback suits the
  dnl root layout, where native/ is a subdirectory of the repository root.
  LIGHTNINGCSS_SHIM_INCLUDE="${LIGHTNINGCSS_SHIM_INCLUDE:-$abs_srcdir/native/include}"
  if test ! -f "$LIGHTNINGCSS_SHIM_INCLUDE/lightningcss_php_shim.h"; then
    AC_MSG_ERROR([lightningcss_php_shim.h not found at $LIGHTNINGCSS_SHIM_INCLUDE])
  fi
  PHP_ADD_INCLUDE([$LIGHTNINGCSS_SHIM_INCLUDE])

  dnl The C hardening belongs here, not only in the build driver: this configure
  dnl path is the canonical artifact path, so a PIE/PECL/distro source build
  dnl must produce the same hardened object as the driver. No -O2 is added
  dnl here — PHP's own default CFLAGS already carry it, and adding it would
  dnl override a DEBUG build's -O0.
  LIGHTNINGCSS_HARDEN_CFLAGS="-fstack-protector-strong -fvisibility=hidden"

  dnl Stack-clash protection where the toolchain supports the flag. Apple clang
  dnl accepts the flag on arm64 but warns "argument unused"; the extension
  dnl builds with -Werror, so the probe must too, or a warning-level rejection
  dnl becomes a hard build failure.
  AC_MSG_CHECKING([whether the C toolchain supports -fstack-clash-protection])
  lightningcss_save_CFLAGS="$CFLAGS"
  CFLAGS="$CFLAGS -Werror -fstack-clash-protection"
  AC_COMPILE_IFELSE(
    [AC_LANG_PROGRAM([], [[return 0;]])],
    [lightningcss_clash=yes], [lightningcss_clash=no])
  CFLAGS="$lightningcss_save_CFLAGS"
  AC_MSG_RESULT([$lightningcss_clash])
  if test "$lightningcss_clash" = "yes"; then
    LIGHTNINGCSS_HARDEN_CFLAGS="$LIGHTNINGCSS_HARDEN_CFLAGS -fstack-clash-protection"
  fi

  dnl _FORTIFY_SOURCE=3 where the toolchain supports it, =2 otherwise. Compile
  dnl with -O2 because older glibc headers emit #warning when optimization is off
  dnl and -Werror turns warnings fatal. Single inner brackets so m4 emits
  dnl valid C in the conftest.
  AC_MSG_CHECKING([which _FORTIFY_SOURCE level the C toolchain supports])
  lightningcss_save_CFLAGS="$CFLAGS"
  CFLAGS="$CFLAGS -Werror -O2 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3"
  AC_COMPILE_IFELSE(
    [AC_LANG_PROGRAM([[#include <string.h>]], [[char b[16]; strcpy(b, "abc"); return (int)strlen(b);]])],
    [lightningcss_fortify=3], [lightningcss_fortify=2])
  CFLAGS="$lightningcss_save_CFLAGS"
  AC_MSG_RESULT([$lightningcss_fortify])
  LIGHTNINGCSS_HARDEN_CFLAGS="$LIGHTNINGCSS_HARDEN_CFLAGS -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=$lightningcss_fortify"

  dnl CET is an x86-64 facility on ELF platforms; applying it on another Tier 1
  dnl target is meaningless, and Apple clang (darwin x86_64) rejects the flag.
  case "$host_cpu:$host_os" in
    x86_64:darwin*|amd64:darwin*) ;;
    x86_64:*|amd64:*) LIGHTNINGCSS_HARDEN_CFLAGS="$LIGHTNINGCSS_HARDEN_CFLAGS -fcf-protection=full" ;;
  esac

  dnl Rust native directory and static archive; overridable so the build driver
  dnl can point at target/debug or an out-of-tree location.
  LIGHTNINGCSS_NATIVE_DIR="${LIGHTNINGCSS_NATIVE_DIR:-$abs_srcdir/native}"
  AC_SUBST([LIGHTNINGCSS_NATIVE_DIR])
  PHP_SUBST([LIGHTNINGCSS_NATIVE_DIR])

  if test "${LIGHTNINGCSS_DEBUG:-0}" = "1"; then
    LIGHTNINGCSS_CARGO_PROFILE=""
    LIGHTNINGCSS_ARCHIVE_DEFAULT="$LIGHTNINGCSS_NATIVE_DIR/target/debug/liblightningcss_php.a"
  else
    LIGHTNINGCSS_CARGO_PROFILE="--release"
    LIGHTNINGCSS_ARCHIVE_DEFAULT="$LIGHTNINGCSS_NATIVE_DIR/target/release/liblightningcss_php.a"
  fi
  LIGHTNINGCSS_ARCHIVE="${LIGHTNINGCSS_ARCHIVE:-$LIGHTNINGCSS_ARCHIVE_DEFAULT}"
  AC_SUBST([LIGHTNINGCSS_ARCHIVE])
  PHP_SUBST([LIGHTNINGCSS_ARCHIVE])
  PHP_SUBST([LIGHTNINGCSS_CARGO_PROFILE])

  dnl Link hardening and symbol isolation; the archive links into the .so.
  dnl Note: PHP_SUBST is mandatory for vars consumed by Makefile.frag;
  dnl autoconf's AC_SUBST is ignored by phpize's Makefile generator.
  LIGHTNINGCSS_LINK_SCRIPT="$abs_srcdir/lightningcss.map"
  if test ! -f "$LIGHTNINGCSS_LINK_SCRIPT"; then
    AC_MSG_ERROR([lightningcss.map not found at $LIGHTNINGCSS_LINK_SCRIPT; it is part of the extension sources])
  fi
  LIGHTNINGCSS_SHARED_LIBADD="$LIGHTNINGCSS_SHARED_LIBADD $LIGHTNINGCSS_ARCHIVE -Wl,--version-script=$LIGHTNINGCSS_LINK_SCRIPT -Wl,--gc-sections -Wl,-z,relro,-z,now,-z,noexecstack"

  PHP_NEW_EXTENSION([lightningcss], [lightningcss.c lightningcss_exception.c], [$ext_shared],,
    [-Wall -Wextra -Werror -Wformat -Wformat-security $LIGHTNINGCSS_HARDEN_CFLAGS])
  PHP_SUBST([LIGHTNINGCSS_SHARED_LIBADD])
  PHP_ADD_MAKEFILE_FRAGMENT()
fi
