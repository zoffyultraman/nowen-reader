import { NextRequest, NextResponse } from "next/server";
import { getRecommendations } from "@/lib/recommendation";

/**
 * GET /api/recommendations - Get personalized recommendations
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get("limit") || "10");
    const excludeRead = searchParams.get("excludeRead") === "true";

    const recommendations = await getRecommendations({ limit, excludeRead });

    return NextResponse.json({
      recommendations,
      total: recommendations.length,
    });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Failed to get recommendations" },
      { status: 500 }
    );
  }
}
