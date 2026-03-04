import { NextRequest, NextResponse } from "next/server";
import { updateComicGroup } from "@/lib/comic-service";

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { groupName } = body;

    if (typeof groupName !== "string") {
      return NextResponse.json({ error: "groupName required" }, { status: 400 });
    }

    await updateComicGroup(id, groupName);
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to update group:", err);
    return NextResponse.json(
      { error: "Failed to update group" },
      { status: 500 }
    );
  }
}
