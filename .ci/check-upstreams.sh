#!/usr/bin/env bash
# Exit 0 for a changed/new snapshot and 3 when it matches the saved snapshot.
set -euo pipefail

state_file=.jenkins-upstreams.state
query_timeout=30
while (($#)); do
    case "$1" in
        --state) state_file=$2; shift 2 ;;
        --timeout) query_timeout=$2; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ "$query_timeout" =~ ^[1-9][0-9]*$ ]] || { echo 'Timeout must be a positive integer' >&2; exit 2; }

new_state=$(mktemp "${TMPDIR:-/tmp}/opencgx-upstreams.XXXXXX")
trap 'rm -f "$new_state"' EXIT
printf 'superproject %s\n' "$(git rev-parse HEAD)" > "$new_state"

if [[ -f .gitmodules ]]; then
    while IFS= read -r key; do
        name=${key#submodule.}
        name=${name%.path}
        path=$(git config -f .gitmodules --get "submodule.${name}.path")
        url=$(git config -f .gitmodules --get "submodule.${name}.url")
        branch=$(git config -f .gitmodules --get "submodule.${name}.branch" || true)
        branch=${branch:-HEAD}
        if [[ "$branch" == '.' ]]; then
            branch=${BRANCH_NAME:-$(git branch --show-current)}
            [[ -n "$branch" ]] || { echo "Cannot resolve inherited branch for $name" >&2; exit 4; }
        fi
        ref=$branch
        [[ "$branch" == HEAD || "$branch" == refs/* ]] || ref="refs/heads/$branch"
        revision=$(timeout "${query_timeout}s" git ls-remote "$url" "$ref" | awk 'NR == 1 { print $1 }')
        [[ -n "$revision" ]] || { echo "No revision found for $name ($url $ref)" >&2; exit 4; }
        printf '%s %s %s %s\n' "$path" "$url" "$ref" "$revision" >> "$new_state"
    done < <(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$' | LC_ALL=C sort)
fi

if [[ -f "$state_file" ]] && cmp -s "$state_file" "$new_state"; then
    echo 'No superproject or upstream submodule changes detected.'
    exit 3
fi
mkdir -p "$(dirname "$state_file")"
cp "$new_state" "${state_file}.pending"
echo 'Upstream revision change detected.'
cat "${state_file}.pending"
