import { NextRequest, NextResponse } from "next/server";
import { updateReadingProgress } from "@/lib/comic-service";

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { page } = body;

    if (typeof page !== "number" || page < 0) {
      return NextResponse.json({ error: "Invalid page number" }, { status: 400 });
    }

    await updateReadingProgress(id, page);
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to update progress:", err);
    return NextResponse.json(
      { error: "Failed to update progress" },
      { status: 500 }
    );
  }
}
