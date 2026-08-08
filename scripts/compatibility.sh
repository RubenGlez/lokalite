#!/bin/sh
set -eu

REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lokalite-compat.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT INT TERM

cd "$REPOSITORY_ROOT"

cargo run --quiet --manifest-path Compatibility/Cargo.toml -- \
  generate-rust "$FIXTURE_ROOT"

LOKALITE_COMPAT_DIR="$FIXTURE_ROOT" swift test \
  --filter CompatibilityOracleTests/testGenerateSwiftFixturesAndVerifyRustCrypto

cargo run --quiet --manifest-path Compatibility/Cargo.toml -- \
  verify-swift "$FIXTURE_ROOT"

LOKALITE_COMPAT_DIR="$FIXTURE_ROOT" swift test \
  --filter CompatibilityOracleTests/testVerifyRustWrittenSchemaFixtures

echo "Swift/Rust compatibility oracle passed with isolated synthetic fixtures."
