#!/bin/sh
set -eu

HOMEBREW_NO_ENV_HINTS=1; export HOMEBREW_NO_ENV_HINTS

test -d "${HOME:?}/.localbrew/.git" ||
  git clone --depth=1 "https://github.com/Homebrew/brew" \
    "${HOME:?}/.localbrew"

test -d "${HOME:?}/.localbrew/.git" ||
  { printf '%s\n' "Error: No ${HOME:?}/.localbrew repository!"; exit 1; }

BREWSHELL="${HOME:?}/.localbrew/bin/bash"
test -x "${BREWSHELL:?}" || BREWSHELL="/bin/sh"; export BREWSHELL

# shellcheck disable=SC2016
command -p env -i            \
  HOME="${HOME:?}"           \
  TERM="${TERM:?}"           \
  BREWSHELL="${BREWSHELL:?}" \
  HOMEBREW_NO_ENV_HINTS=1    \
  "$(command -v sh)" -c '
eval "$("${HOME:?}/.localbrew/bin/brew" shellenv)" ||
  { printf "%s\n" "Error: Failed to setup brew environment!"; exit 1; }

printf "%s\n" "$("${HOME:?}/.localbrew/bin/brew" --prefix)" |
  grep -E "(/sw|/usr/local|/usr/opt|/opt)" &&
    { printf "%s\n" "Error: Unexpected Homebrew prefix!"; exit 1; }

	printf "\r%s\r" "* Updating brew ..."
"${HOME:?}/.localbrew/bin/brew" update --force --quiet
"${HOME:?}/.localbrew/bin/brew" install bash 2> /dev/null

chmod -R go-w                                             \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)"/share/zsh \
    > /dev/null 2>&1

BREWMPATH="$("${HOME:?}/.localbrew/bin/brew" --prefix)"
BREWBPATH="${BREWMPATH:?}/bin"
BREWSPATH="${BREWMPATH:?}/sbin"
POSIXPATH="$(command -p getconf PATH)"
INSIDEPATH="${BREWBPATH:?}:${BREWSPATH:?}:${POSIXPATH:?}"

printf "%s\n" "${POSIXPATH:?}" |
  grep -E "(/sw|/usr/local|/usr/opt|/opt)" &&
    { printf "%s\n" "Error: Bad POSIXPATH: ${POSIXPATH:?}"; exit 1; }

printf "[localbrew] Using Homebrew prefix: %s\n" \
  "$("${HOME:?}/.localbrew/bin/brew" --prefix)"

printf "[localbrew] Using PATH: %s\n" "${INSIDEPATH:?}" |
  sed "s#${HOME:?}#$HOME#g"

command -p exec env -i       \
  HOME="${HOME:?}"           \
  PATH="${INSIDEPATH:?}"     \
  TERM="${TERM:?}"           \
  PS1="[localbrew] \s-\v\$ " \
  ${BREWSHELL:?}
'
