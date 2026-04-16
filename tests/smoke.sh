#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT_DIR/wifi-cracker.sh"
bash -n "$ROOT_DIR/lib/"*.sh

echo "syntax-ok"
