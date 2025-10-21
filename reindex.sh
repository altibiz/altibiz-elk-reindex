#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-}"
INDICES_FILE="${2:-}"

source $ENV_FILE
curl_src() {
	path="${1:-}"
	curl -s $SRC_CURL_ARGS -H "Authorization: ApiKey $SRC_API_KEY" "$SRC_HOST$path" "${@:2}"
}
curl_dest() {
	path="${1:-}"
	curl -s $DEST_CURL_ARGS -H "Authorization: ApiKey $DEST_API_KEY" "$DEST_HOST$path" "${@:2}"
}

TMP_DIR=$(mktemp -d)

cleanup() {
	rm -rf "$TMP_DIR"
	rm -f "$INDICES_FILE"
}
trap cleanup EXIT

while IFS= read -r index; do
	printf "\n\nProcessing $index...\n"

	curl_dest "/$index" -X DELETE >/dev/null
	printf "\nDeleted $index from destination\n"

	curl_src "/$index" | jq "{
    settings: .[\"$index\"].settings.index |
      del(.provided_name, .uuid, .creation_date, .version, .routing),
    mappings: .[\"$index\"].mappings
  }" >$TMP_DIR/$index-config.json
	printf "\nFetched $index config from source: '$(cat "$TMP_DIR/$index-config.json")'\n"

	curl_dest "/$index" -X PUT \
		-H 'Content-Type: application/json' \
		-d @$TMP_DIR/$index-config.json >/dev/null
	printf "\nAdded $index to destination\n"

	curl_dest "/_reindex" -X POST \
		-H 'Content-Type: application/json' -d"{
      \"source\": {
        \"remote\": {
          \"host\": \"$SRC_HOST\",
	  \"headers\": {
            \"Authorization\": \"ApiKey $SRC_API_KEY\"
          }
        },
        \"index\": \"$index\"
      },
      \"dest\": {\"index\": \"$index\"}
    }" >/dev/null
	printf "\nReindexed $index from source to destination\n"
done <"$INDICES_FILE"

printf "\nReindexing complete!\n"
