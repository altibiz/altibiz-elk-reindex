#!/usr/bin/env bash
set -euo pipefail

printf "\n"
printf "╔════════════════════════════════════════════════════════╗\n"
printf "║     Elasticsearch Index Migration Tool                 ║\n"
printf "║     Documentation/Banner/Thingie xd                    ║\n"
printf "╠════════════════════════════════════════════════════════╣\n"
printf "║  1. Check connectivity                                 ║\n"
printf "║  2. Fetch requested indices and check in with you      ║\n"
printf "║  3. Reindex one by one :)                              ║\n"
printf "╚════════════════════════════════════════════════════════╝\n"
printf "\n"

ENV_FILE="${1:-.env}"
source "$ENV_FILE"
curl_src() {
	path="${1:-}"
	curl -s $SRC_CURL_ARGS -H "Authorization: ApiKey $SRC_API_KEY" "$SRC_HOST$path" "${@:2}"
}
curl_dest() {
	path="${1:-}"
	curl -s $DEST_CURL_ARGS -H "Authorization: ApiKey $DEST_API_KEY" "$DEST_HOST$path" "${@:2}"
}

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

printf "\n\n1. Checking connectivity...\n"
printf "Source: \n"
if curl_src >/dev/null; then
	printf "Connected\n"
	curl_src | jq -r '.version.number'
else
	printf "Failed\n"
	exit 1
fi
printf "Destination: \n"
if curl_dest >/dev/null; then
	printf "Connected\n"
	curl_dest | jq -r '.version.number'
else
	printf "Failed\n"
	exit 1
fi

indices=$(curl_src "/_cat/indices/$INDEX_PATTERN?h=index" |
	grep -v "^\." |
	grep -v "^apm-" |
	grep -v "^metrics-endpoint-")
printf "\n\n2. About to migrate these indices:\n"
printf "\n%s\n\n" "${indices[@]}"
read -p "Continue? (y/n): " -n 1 -r
printf "\n"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	printf "Aborted!\n"
	exit 0
fi
INDICES_FILE=$(mktemp)
echo "$indices" >"$INDICES_FILE"

UNIT_NAME="altibiz-elk-reindex-$(date +%s)"
printf "\n\n3. Starting reindex in systemd scope: %s\n" "$UNIT_NAME"
systemd-run --user --unit="$UNIT_NAME" \
	--setenv=PATH="$PATH" \
	--working-directory="$PWD" \
	bash -c "./reindex.sh '$ENV_FILE' '$INDICES_FILE'" \
	&>/dev/null &
disown %-
printf "\nStarted! Monitor with:\n"
printf "journalctl --user -fxeu %s\n" "$UNIT_NAME"
printf "systemctl --user status %s\n" "$UNIT_NAME"
