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

test -d "${HOME:-}" 2> /dev/null ||
  { printf '%s\n' "Error: ${HOME:-} non-existent."; exit 1; }

test "$(whoami 2> /dev/null)" "!=" "root" 2> /dev/null ||
  { printf '%s\n' "Error: Running as root is not allowed!"; exit 1; }

# Drop sudo credential caching before we start, just in case.
env PATH="$(command -p env getconf PATH)" env sudo -k > /dev/null 2>&1 || true
$(command -v sudo || printf '%s\n' "true") -k > /dev/null 2>&1 || true

SHNOPROFILE="-i"; SHNORC="-i"
"$(command -v sh || printf '%s\n' "sh")" --version 2> /dev/null |
  grep -q "bash" && { SHNOPROFILE="--noprofile"; SHNORC="--norc"; }
export SHNOPROFILE SHNORC

HOMEBREW_DISPLAY_INSTALL_TIMES=1; export HOMEBREW_DISPLAY_INSTALL_TIMES
HOMEBREW_NO_ENV_HINTS=1; export HOMEBREW_NO_ENV_HINTS
HOMEBREW_VERBOSE=1; export HOMEBREW_VERBOSE
HOMEBREW_VERBOSE_USING_DOTS=1; export HOMEBREW_VERBOSE_USING_DOTS
HOMEBREW_NO_ANALYTICS=1; export HOMEBREW_NO_ANALYTICS

PATH_BLACKLIST='"(/opt/local|/sw|/usr/local|/usr/opt|/usr/pkg)"'

test -d "${HOME:?}/.localbrew/.git" 2> /dev/null ||
  git clone --depth=1 "https://github.com/Homebrew/brew" \
    "${HOME:?}/.localbrew"

test -d "${HOME:?}/.localbrew/.git" 2> /dev/null ||
  { printf '%s\n' "Error: No ${HOME:?}/.localbrew repository!"; exit 1; }

BREWSHELL="${HOME:?}/.localbrew/bin/bash"
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
  "$(command -v sh || printf '%s\n' "sh")" \
    ${SHNOPROFILE:?} ${SHNORC:?} -c '
eval "$("${HOME:?}/.localbrew/bin/brew" shellenv)" ||
  { printf "%s\n" "Error: Failed to setup brew environment!"; exit 1; }

printf "%s\n" "$("${HOME:?}/.localbrew/bin/brew" --prefix)" |
  grep -q -E "${PATH_BLACKLIST:?}" &&
    { printf "%s\n" "Error: Unexpected Homebrew prefix!"; exit 1; }

printf "\r%s"   "* Updating ... "
"${HOME:?}/.localbrew/bin/brew" update --force --quiet
"${HOME:?}/.localbrew/bin/brew" install --verbose bash 2> /dev/null
printf "\r%s\r" "               "

chmod -R go-w                                             \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)"/share/zsh \
    > /dev/null 2>&1

BREWMPATH="$("${HOME:?}/.localbrew/bin/brew" --prefix)"
BREWBPATH="${BREWMPATH:?}/bin"
BREWSPATH="${BREWMPATH:?}/sbin"
POSIXPATH="$(command -p getconf PATH)"
INSIDEPATH="${BREWBPATH:?}:${BREWSPATH:?}:${POSIXPATH:?}"

printf "%s\n" "${INSIDEPATH:?}" |
  grep -q -E "${PATH_BLACKLIST:?}" &&
    { printf "%s\n" "Error: Bad PATH: ${INSIDEPATH:?}"; exit 1; }

printf "[localbrew] Using Homebrew prefix: %s\n" \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)" |
    sed "s#${HOME:?}#\$HOME#g" || true

printf "[localbrew] Using PATH: %s\n" "${INSIDEPATH:?}" |
  sed "s#${HOME:?}#\$HOME#g" || true

command -p exec env -i          \
  HOME="${HOME:?}"              \
  PATH="${INSIDEPATH:?}"        \
  PS1="[localbrew] \h:\W \u\$ " \
  TERM="${TERM:?}"              \
  "${BREWSHELL:?}"              \
    ${SHNOPROFILE:?} ${SHNORC:?}
'
