import { NextRequest, NextResponse } from "next/server";
import { getSimilarComics } from "@/lib/recommendation";

/**
 * GET /api/recommendations/similar/[id] - Get similar comics
 */
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get("limit") || "5");

    const similar = await getSimilarComics(id, limit);

    return NextResponse.json({
      similar,
      total: similar.length,
    });
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Failed to get similar comics" },
      { status: 500 }
    );
  }
}
