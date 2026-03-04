import { NextResponse } from "next/server";
import { applyMetadata } from "@/lib/metadata-scraper";

export async function POST(request: Request) {
  try {
    const { comicId, metadata } = await request.json();

    if (!comicId || !metadata) {
      return NextResponse.json(
        { error: "comicId and metadata are required" },
        { status: 400 }
      );
    }

    const comic = await applyMetadata(comicId, metadata);
    return NextResponse.json({ comic });
  } catch (err) {
    console.error("Apply metadata error:", err);
    return NextResponse.json(
      { error: "Failed to apply metadata" },
      { status: 500 }
    );
  }
}
