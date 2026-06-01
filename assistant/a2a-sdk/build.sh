#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
npx esbuild entry.js --bundle --format=iife --platform=browser --target=es2020 --outfile=../a2a-sdk.bundle.js
echo "Bundle written to assistant/a2a-sdk.bundle.js"
