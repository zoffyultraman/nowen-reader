import { NextRequest, NextResponse } from "next/server";
import { getComicById } from "@/lib/comic-service";

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const comic = await getComicById(id);

    if (!comic) {
      return NextResponse.json({ error: "Comic not found" }, { status: 404 });
    }

    return NextResponse.json(comic);
  } catch (err) {
    console.error("Failed to get comic:", err);
    return NextResponse.json(
      { error: "Failed to get comic" },
      { status: 500 }
    );
  }
}
