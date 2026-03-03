#!/usr/bin/env bash

set -euo pipefail

target_dir="${1:-.}"

if [[ ! -d "${target_dir}" ]]; then
	echo "Error: directory does not exist: ${target_dir}" >&2
	exit 1
fi

cd "${target_dir}"

shopt -s nullglob

chk_dirs=()
for path in chk*; do
	if [[ -d "${path}" && "${path}" =~ ^chk[0-9]+$ ]]; then
		chk_dirs+=("${path}")
	fi
done

if [[ ${#chk_dirs[@]} -eq 0 ]]; then
	echo "Error: no checkpoint directories matching ^chk[0-9]+$ in ${target_dir}" >&2
	exit 1
fi

last_chk="$(printf '%s\n' "${chk_dirs[@]}" | sort -V | tail -n 1)"

if [[ -e "last_chk" || -L "last_chk" ]]; then
	rm -f "last_chk"
fi

ln -s "${last_chk}" "last_chk"
echo "Created symlink: ${target_dir}/last_chk -> ${last_chk}"
