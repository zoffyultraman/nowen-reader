import { NextRequest, NextResponse } from "next/server";
import { toggleFavorite } from "@/lib/comic-service";

export async function PUT(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const comic = await toggleFavorite(id);

    if (!comic) {
      return NextResponse.json({ error: "Comic not found" }, { status: 404 });
    }

    return NextResponse.json({ success: true, isFavorite: comic.isFavorite });
  } catch (err) {
    console.error("Failed to toggle favorite:", err);
    return NextResponse.json(
      { error: "Failed to toggle favorite" },
      { status: 500 }
    );
  }
}
