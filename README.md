# altibiz-elk-reindex

reindex elasticsearch indices from one cluster to another

## what it does

- fetches indices matching a pattern from source cluster
- creates them on destination cluster
- reindexes all the data
- runs in background via systemd so you can close your terminal

## how to use

```sh
git clone https://github.com/altibiz/altibiz-elk-reindex
cd altibiz-elk-reindex
cp .env.example .env
vim .env  # fill in your cluster details
./main.sh
```

the script will start reindexing in the background and give you a command to monitor progress

## config (`.env`)

```env
# source cluster
SRC_HOST="https://source-elk.example.com"
SRC_API_KEY="your-source-api-key"
SRC_CURL_ARGS=""  # optional: extra curl args like "--insecure"

# destination cluster
DEST_HOST="https://dest-elk.example.com"
DEST_API_KEY="your-dest-api-key"
DEST_CURL_ARGS=""

# which indices to copy
INDEX_PATTERN="my-index-*"  # supports wildcards
```

## monitoring

after starting, use the journalctl command it prints to watch progress:

```sh
journalctl --user -u altibiz-elk-reindex-<timestamp> -f
```

## dependencies

- bash
- curl
- jq
- systemd

## nix

if you're on nix:

```sh
nix develop  # dev shell with all deps
```
