#!/bin/sh
# vim: set ts=2 sw=2 tw=0 expandtab colorcolumn=80 :
# SPDX-License-Identifier: 0BSD

###############################################################################
#
# Copyright (c) 2022-2023 Jeffrey H. Johnson <trnsz@pobox.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
###############################################################################

set -eu

test "$(whoami 2> /dev/null)" "!=" "root" 2> /dev/null ||
  { printf '%s\n' "Error: Running as root is not allowed!"; exit 1; }

test -d "${HOME:-}" 2> /dev/null ||
  { printf '%s\n' "Error: ${HOME:-} non-existent."; exit 1; }

test -z "${1:-}" 2> /dev/null &&
  { LOCALBREW_DIR="${HOME:?}/.localbrew"; export LOCALBREW_DIR; }

test -n "${1:-}" 2> /dev/null &&
  { LOCALBREW_DIR="${1:-}"; export LOCALBREW_DIR; }

printf '%s\n' "[localbrew] Using \"${LOCALBREW_DIR:?}\" ..."

# Change default optimization to -O2 #{Hardware.oldest_cpu} for source builds.
patch_brew () {
sed -i '' -e 's/"Os"/"O2"/' \
  "${LOCALBREW_DIR:?}/Library/Homebrew/extend/ENV/super.rb" 2> /dev/null

sed -i '' -e 's/= determine_optflags/= "-march=#{Hardware.oldest_cpu}"/' \
  "${LOCALBREW_DIR:?}/Library/Homebrew/extend/ENV/super.rb" 2> /dev/null

( cd "${LOCALBREW_DIR:?}/Library/Homebrew/extend/ENV" &&
    git commit -a -m "localbrew patch" --author="localbrew.sh <local@brew>" \
      -n --no-gpg-sign || true ) || true
}

# Drop sudo credential caching before we start, just in case.
env PATH="$(command -p env getconf PATH)" env sudo -k > /dev/null 2>&1 || true
$(command -v sudo || printf '%s\n' "true") -k > /dev/null 2>&1 || true

SHNOPROFILE="-i"; SHNORC="-i"
"$(command -v sh || printf '%s\n' "sh")" --version 2> /dev/null |
  grep -q "bash" && { SHNOPROFILE="--noprofile"; SHNORC="--norc"; }
export SHNOPROFILE SHNORC

HOMEBREW_DISPLAY_INSTALL_TIMES=1; export HOMEBREW_DISPLAY_INSTALL_TIMES
HOMEBREW_NO_ANALYTICS=1; export HOMEBREW_NO_ANALYTICS
HOMEBREW_NO_AUTO_UPDATE=1; export HOMEBREW_NO_AUTO_UPDATE
HOMEBREW_NO_BOOTSNAP=1; export HOMEBREW_NO_BOOTSNAP
HOMEBREW_NO_ENV_FILTERING=1; export HOMEBREW_NO_ENV_FILTERING
HOMEBREW_NO_ENV_HINTS=1; export HOMEBREW_NO_ENV_HINTS
HOMEBREW_NO_INSTALL_CLEANUP=1; export HOMEBREW_NO_INSTALL_CLEANUP
HOMEBREW_VERBOSE=1; export HOMEBREW_VERBOSE
HOMEBREW_VERBOSE_USING_DOTS=1; export HOMEBREW_VERBOSE_USING_DOTS

PATH_BLACKLIST='"(/opt/local|/sw|/usr/local|/usr/opt|/usr/pkg)"'

test -d "${LOCALBREW_DIR:?}/.git" 2> /dev/null ||
  git clone --depth=1 "https://github.com/Homebrew/brew" \
    "${LOCALBREW_DIR:?}" && \
      patch_brew

test -d "${LOCALBREW_DIR:?}/.git" 2> /dev/null ||
  { printf '%s\n' "Error: No \"${LOCALBREW_DIR:?}\" repository!"; exit 1; }

BREWSHELL="${LOCALBREW_DIR:?}/bin/bash"
test -x "${BREWSHELL:?}" 2> /dev/null || BREWSHELL="/bin/sh"; export BREWSHELL

# shellcheck disable=SC2016
command -p env -i                          \
  BREWSHELL="${BREWSHELL:?}"               \
  HOME="${HOME:?}"                         \
  HOMEBREW_NO_ENV_HINTS=1                  \
  HOMEBREW_NO_ANALYTICS=1                  \
  PATH_BLACKLIST="${PATH_BLACKLIST:?}"     \
  SHNOPROFILE="${SHNOPROFILE:?}"           \
  SHNORC="${SHNORC:?}"                     \
  TERM="${TERM:?}"                         \
  LOCALBREW_DIR="${LOCALBREW_DIR:?}"       \
  "$(command -v sh || printf '%s\n' "sh")" \
    ${SHNOPROFILE:?} ${SHNORC:?} -c '
eval "$("${LOCALBREW_DIR:?}/bin/brew" shellenv)" ||
  { printf "%s\n" "Error: Failed to setup brew environment!"; exit 1; }

printf "%s\n" "$("${LOCALBREW_DIR:?}/bin/brew" --prefix)" |
  grep -q -E "${PATH_BLACKLIST:?}" &&
    { printf "%s\n" "Error: Unexpected Homebrew prefix!"; exit 1; }

printf "%s\n"   "[localbrew] brew update ... "
env HOMEBREW_DEVELOPER=1 \
  "${LOCALBREW_DIR:?}/bin/brew" update

printf "%s\n"   "[localbrew] brew install bash ... "
env HOMEBREW_NO_AUTO_UPDATE=1     \
    HOMEBREW_NO_INSTALL_CLEANUP=1 \
    HOMEBREW_NO_INSTALL_UPGRADE=1 \
    HOMEBREW_DEVELOPER=1          \
  "${LOCALBREW_DIR:?}/bin/brew" install -v --no-quarantine "bash"

chmod -R go-w                                             \
  "$("${LOCALBREW_DIR:?}/bin/brew" --prefix)"/share/zsh \
    > /dev/null 2>&1

BREWMPATH="$("${LOCALBREW_DIR:?}/bin/brew" --prefix)"
BREWBPATH="${BREWMPATH:?}/bin"
BREWSPATH="${BREWMPATH:?}/sbin"
POSIXPATH="$(command -p getconf PATH)"
INSIDEPATH="${BREWBPATH:?}:${BREWSPATH:?}:${POSIXPATH:?}"

printf "%s\n" "${INSIDEPATH:?}" |
  grep -q -E "${PATH_BLACKLIST:?}" &&
    { printf "%s\n" "Error: Bad PATH: ${INSIDEPATH:?}"; exit 1; }

printf "[localbrew] Using Homebrew prefix: %s\n" \
  "$("${LOCALBREW_DIR:?}/bin/brew" --prefix)" |
    sed "s#${HOME:?}#\$HOME#g" || true

printf "[localbrew] Using PATH: %s\n" "${INSIDEPATH:?}" |
  sed "s#${HOME:?}#\$HOME#g" || true

command -p exec env -i          \
  HOME="${HOME:?}"              \
  PATH="${INSIDEPATH:?}"        \
  PS1="[localbrew] \h:\W \u\$ " \
  TERM="${TERM:?}"              \
  HOMEBREW_DEVELOPER=1          \
  HOMEBREW_NO_AUTO_UPDATE=1     \
  "${BREWSHELL:?}"              \
    ${SHNOPROFILE:?} ${SHNORC:?}
'
