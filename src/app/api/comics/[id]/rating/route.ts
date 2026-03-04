import { NextRequest, NextResponse } from "next/server";
import { updateRating } from "@/lib/comic-service";

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { rating } = body;

    if (rating !== null && (typeof rating !== "number" || rating < 1 || rating > 5)) {
      return NextResponse.json({ error: "Rating must be 1-5 or null" }, { status: 400 });
    }

    await updateRating(id, rating);
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to update rating:", err);
    return NextResponse.json(
      { error: "Failed to update rating" },
      { status: 500 }
    );
  }
}
