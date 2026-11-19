#!/bin/sh
# Confirm that rtach forwards executable arguments, including shell flags.
set -eu
rtach=${1:?Usage: test-command-arguments.sh /path/to/rtach}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

wait_for_file() {
    path=$1
    i=0
    while [ ! -e "$path" ] && [ "$i" -lt 100 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    [ -e "$path" ] || { echo "rtach command did not run: $path" >&2; exit 1; }
}

# -c is sh's argument, despite also being an rtach option.
"$rtach" -n "$tmp/sh.sock" /bin/sh -c 'printf "%s|%s" "$0" "$1" > "$2"' zero one "$tmp/sh-result"
wait_for_file "$tmp/sh-result"
[ "$(cat "$tmp/sh-result")" = "zero|one" ] || {
    echo "rtach failed to forward sh argv" >&2
    exit 1
}

# -l must reach bash; it is not a command to execute or a discarded flag.
"$rtach" -n "$tmp/bash.sock" /bin/bash -l -c \
    'shopt -q login_shell && printf "login-shell" > "$1"' unused "$tmp/bash-result"
wait_for_file "$tmp/bash-result"
[ "$(cat "$tmp/bash-result")" = "login-shell" ] || {
    echo "rtach failed to start bash as a login shell" >&2
    exit 1
}
echo "PASS: rtach forwards program arguments and bash login flag"
