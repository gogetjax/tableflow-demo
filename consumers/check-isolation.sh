#!/usr/bin/env bash
# Fails if consumer code or config (not Markdown, not comments, not this script) carries any
# Confluent connection material: Confluent Cloud hostnames, CONFLUENT_* variables, Schema
# Registry or bootstrap-server settings, SASL settings, or Kafka/SR cluster endpoints.
# Prose mentioning the word "Confluent" (docstrings, table headers) is allowed; the point is
# that nothing on the read side can *reach* Confluent. Run by consumers-check.yml.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
pattern='confluent\.cloud|CONFLUENT_[A-Z]|schema[._-]registry|bootstrap[._-]servers|sasl\.|pkc-[a-z0-9]{4,}|psrc-[a-z0-9]{4,}|lsrc-[a-z0-9]{4,}|api\.confluent'
hits=$(grep -rIn --exclude='*.md' --exclude='check-isolation.sh' -e '' consumers/ \
  | sed -E 's/^([^:]+:[0-9]+:)[[:space:]]*(#|--|\/\/).*$/\1/' \
  | sed -E 's/[[:space:]]+(#|--|\/\/).*$//' \
  | grep -iE "$pattern" || true)
if [[ -n "$hits" ]]; then
  echo "Confluent connection material found in consumers/ code:"; echo "$hits"; exit 1
fi
echo "ok: no Confluent connection material in consumers/ code"
