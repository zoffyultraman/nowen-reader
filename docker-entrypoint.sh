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
echo "[init] Running prisma db push..."
su-exec nextjs npx prisma db push --schema ./prisma/schema.prisma --accept-data-loss --skip-generate || {
    echo "[warn] prisma db push exited with code $?, attempting fallback..."
    # Fallback: try without prisma.config.ts by setting env directly
    su-exec nextjs DATABASE_URL="${DATABASE_URL}" npx prisma db push --schema ./prisma/schema.prisma --accept-data-loss --skip-generate 2>&1 || {
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
