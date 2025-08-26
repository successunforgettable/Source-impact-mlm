#!/usr/bin/env bash
set -euo pipefail

echo "=== RUNTIME CHECK: Listing /usr/lib/cgi-bin ==="
ls -la /usr/lib/cgi-bin || true
echo "=== HEAD of env.cgi ==="
head -n 5 /usr/lib/cgi-bin/env.cgi || true
echo "=== HEAD of goto ==="
head -n 5 /usr/lib/cgi-bin/goto || true

echo "=== Starting Apache ==="
exec apache2ctl -D FOREGROUND