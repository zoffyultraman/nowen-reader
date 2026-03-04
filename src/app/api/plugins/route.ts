import { NextRequest, NextResponse } from "next/server";
import { pluginManager } from "@/lib/plugin-system";

/**
 * GET /api/plugins - List all plugins
 */
export async function GET() {
  const plugins = pluginManager.getPlugins();

  return NextResponse.json({
    plugins: plugins.map((p) => ({
      id: p.manifest.id,
      name: p.manifest.name,
      version: p.manifest.version,
      description: p.manifest.description,
      author: p.manifest.author,
      enabled: p.enabled,
      permissions: p.manifest.permissions || [],
      settings: p.settings,
    })),
  });
}

/**
 * POST /api/plugins - Enable/disable a plugin or update settings
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    if (body.action === "toggle") {
      pluginManager.setPluginEnabled(body.pluginId, body.enabled);
      return NextResponse.json({ success: true });
    }

    if (body.action === "settings") {
      const plugin = pluginManager.getPlugin(body.pluginId);
      if (!plugin) {
        return NextResponse.json({ error: "Plugin not found" }, { status: 404 });
      }
      Object.assign(plugin.settings, body.settings);
      return NextResponse.json({ success: true });
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Failed" },
      { status: 500 }
    );
  }
}
