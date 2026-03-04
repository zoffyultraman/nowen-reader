import { NextRequest, NextResponse } from "next/server";
import { deleteComic } from "@/lib/comic-service";

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const result = await deleteComic(id);

    if (!result) {
      return NextResponse.json({ error: "Comic not found" }, { status: 404 });
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to delete comic:", err);
    return NextResponse.json(
      { error: "Failed to delete comic" },
      { status: 500 }
    );
  }
}
