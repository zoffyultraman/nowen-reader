#!/bin/sh
set -e

# ============================================================
# NowenReader Docker Entrypoint
# ============================================================

echo "========================================="
echo "  NowenReader - Starting up..."
echo "========================================="

# Ensure directories exist
mkdir -p /data
mkdir -p /app/.cache/thumbnails
mkdir -p /app/comics

# Fix permissions for mounted volumes (NAS/Docker)
chown -R nextjs:nodejs /data /app/.cache /app/comics 2>/dev/null || true

# Set environment
export DATABASE_URL="${DATABASE_URL:-file:/data/nowen-reader.db}"
export COMICS_DIR="${COMICS_DIR:-/app/comics}"

# Initialize database (as nextjs user)
echo "[init] Checking database..."
if [ ! -f /data/nowen-reader.db ]; then
    echo "[init] Creating database for first time..."
fi

# Export DATABASE_URL so child processes (su-exec) inherit it
export DATABASE_URL

echo "[init] Running prisma db push..."
# Use node to run prisma directly (npx is not available in standalone image)
PRISMA_CMD="node ./node_modules/prisma/build/index.js"
su-exec nextjs $PRISMA_CMD db push --schema ./prisma/schema.prisma --accept-data-loss --skip-generate 2>&1 || {
    echo "[warn] prisma db push exited with code $?, attempting fallback..."
    # Fallback: use env command for su-exec (su-exec doesn't support inline VAR=val)
    su-exec nextjs env DATABASE_URL="${DATABASE_URL}" $PRISMA_CMD db push --schema ./prisma/schema.prisma --accept-data-loss --skip-generate 2>&1 || {
        echo "[error] Database initialization failed!"
        exit 1
    }
}

echo "[init] Database ready."
echo "[init] Comics directory: ${COMICS_DIR}"
echo "[init] Listening on port ${PORT:-3000}"
echo "========================================="

# Start Next.js as non-root user
exec su-exec nextjs node server.js
