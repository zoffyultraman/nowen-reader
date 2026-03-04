import { NextRequest, NextResponse } from "next/server";
import { exportSyncData, importSyncData, performWebDAVSync } from "@/lib/cloud-sync";
import type { SyncConfig, SyncData } from "@/lib/cloud-sync";

/**
 * GET /api/sync - Export local sync data
 */
export async function GET(request: NextRequest) {
  try {
    const deviceId = request.headers.get("x-device-id") || "default";
    const data = await exportSyncData(deviceId);
    return NextResponse.json(data);
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Export failed" },
      { status: 500 }
    );
  }
}

/**
 * POST /api/sync - Import sync data or trigger WebDAV sync
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    // WebDAV sync
    if (body.action === "webdav-sync") {
      const config: SyncConfig = body.config;
      const deviceId = body.deviceId || "default";
      const result = await performWebDAVSync(config, deviceId);
      return NextResponse.json(result);
    }

    // Direct import
    if (body.action === "import") {
      const syncData: SyncData = body.data;
      if (!syncData || !syncData.comics) {
        return NextResponse.json({ error: "Invalid sync data" }, { status: 400 });
      }
      const result = await importSyncData(syncData);
      return NextResponse.json({
        success: true,
        ...result,
      });
    }

    // Test WebDAV connection
    if (body.action === "test-connection") {
      const { WebDAVSync: WebDAVSyncClass } = await import("@/lib/cloud-sync");
      const client = new WebDAVSyncClass(body.url, body.username, body.password);
      const connected = await client.testConnection();
      return NextResponse.json({ connected });
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Sync failed" },
      { status: 500 }
    );
  }
}
