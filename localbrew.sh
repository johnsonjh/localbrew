#!/bin/sh
# vim: set ts=2 sw=2 tw=0 expandtab colorcolumn=80 :
# SPDX-License-Identifier: FSFAP

########################################################################
#                                                                      #
# Copyright (c) 2022 Jeffrey H. Johnson <trnsz@pobox.com>              #
#                                                                      #
# Copying and distribution of this file, with or without modification, #
# are permitted in any medium without royalty provided the copyright   #
# notice and this notice are preserved.  This file is offered "AS-IS", #
# without any warranty.                                                #
#                                                                      #
########################################################################

set -eu

test -d "${HOME:?}" 2> /dev/null ||
  { printf '%s\n' "Error: ${HOME:?} non-existent."; exit 1; }

test "$(whoami 2> /dev/null)" "!=" "root" 2> /dev/null ||
  { printf '%s\n' "Error: Running as root is not allowed!"; exit 1; }

# Drop sudo credential caching before we start, just in case.
env PATH="$(command -p env getconf PATH)" env sudo -k > /dev/null 2>&1 || true
$(command -v sudo || printf '%s\n' "true") -k > /dev/null 2>&1 || true

SHNOPROFILE=" "; SHNORC=" "
"$(command -v sh || printf '%s\n' "sh")" --version 2> /dev/null |
  grep -q "bash" && { SHNOPROFILE="--noprofile"; SHNORC="--norc"; }
export SHNOPROFILE SHNORC

HOMEBREW_NO_ENV_HINTS=1; export HOMEBREW_NO_ENV_HINTS

test -d "${HOME:?}/.localbrew/.git" 2> /dev/null ||
  git clone --depth=1 "https://github.com/Homebrew/brew" \
    "${HOME:?}/.localbrew"

test -d "${HOME:?}/.localbrew/.git" 2> /dev/null ||
  { printf '%s\n' "Error: No ${HOME:?}/.localbrew repository!"; exit 1; }

BREWSHELL="${HOME:?}/.localbrew/bin/bash"
test -x "${BREWSHELL:?}" 2> /dev/null || BREWSHELL="/bin/sh"export BREWSHELL

# shellcheck disable=SC2016
command -p env -i                          \
  HOME="${HOME:?}"                         \
  TERM="${TERM:?}"                         \
  BREWSHELL="${BREWSHELL:?}"               \
  HOMEBREW_NO_ENV_HINTS=1                  \
  "$(command -v sh || printf '%s\n' "sh")" \
    "${SHNOPROFILE:-}" "${SHNORC:-}" -c '
eval "$("${HOME:?}/.localbrew/bin/brew" shellenv)" ||
  { printf "%s\n" "Error: Failed to setup brew environment!"; exit 1; }

printf "%s\n" "$("${HOME:?}/.localbrew/bin/brew" --prefix)" |
  grep -q -E "(/sw|/usr/local|/usr/opt|/opt)" &&
    { printf "%s\n" "Error: Unexpected Homebrew prefix!"; exit 1; }

printf "\r%s\r" "[localbrew] Updating Homebrew ..."
"${HOME:?}/.localbrew/bin/brew" update --force --quiet
"${HOME:?}/.localbrew/bin/brew" install bash 2> /dev/null
printf "\r%s\r" "                                 "

chmod -R go-w                                             \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)"/share/zsh \
    > /dev/null 2>&1

BREWMPATH="$("${HOME:?}/.localbrew/bin/brew" --prefix)"
BREWBPATH="${BREWMPATH:?}/bin"
BREWSPATH="${BREWMPATH:?}/sbin"
POSIXPATH="$(command -p getconf PATH)"
INSIDEPATH="${BREWBPATH:?}:${BREWSPATH:?}:${POSIXPATH:?}"

printf "%s\n" "${INSIDEPATH:?}" |
  grep -q -E "(/sw|/usr/local|/usr/opt|/opt)" &&
    { printf "%s\n" "Error: Bad PATH: ${INSIDEPATH:?}"; exit 1; }

printf "[localbrew] Using Homebrew prefix: %s\n" \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)" |
    sed "s#${HOME:?}#\$HOME#g" || true

printf "[localbrew] Using PATH: %s\n" "${INSIDEPATH:?}" |
  sed "s#${HOME:?}#\$HOME#g" || true

command -p exec env -i       \
  HOME="${HOME:?}"           \
  PATH="${INSIDEPATH:?}"     \
  TERM="${TERM:?}"           \
  PS1="localbrew@\h:\W \u\$" \
  "${BREWSHELL:?}" "${SHNORC:-}" "${SHNOPROFILE:-}"
'
