import { NextRequest, NextResponse } from "next/server";
import { addTagsToComic, removeTagFromComic } from "@/lib/comic-service";

// Add tags to a comic
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { tags } = body;

    if (!Array.isArray(tags) || tags.length === 0) {
      return NextResponse.json({ error: "Tags array required" }, { status: 400 });
    }

    await addTagsToComic(
      id,
      tags.map((t: string) => t.trim()).filter(Boolean)
    );

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to add tags:", err);
    return NextResponse.json(
      { error: "Failed to add tags" },
      { status: 500 }
    );
  }
}

// Remove a tag from a comic
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { tag } = body;

    if (!tag || typeof tag !== "string") {
      return NextResponse.json({ error: "Tag name required" }, { status: 400 });
    }

    await removeTagFromComic(id, tag.trim());
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to remove tag:", err);
    return NextResponse.json(
      { error: "Failed to remove tag" },
      { status: 500 }
    );
  }
}
