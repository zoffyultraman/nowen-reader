import { NextResponse } from "next/server";
import { getAllGroups } from "@/lib/comic-service";

export async function GET() {
  try {
    const groups = await getAllGroups();
    return NextResponse.json({ groups });
  } catch (err) {
    console.error("Failed to fetch groups:", err);
    return NextResponse.json(
      { error: "Failed to fetch groups" },
      { status: 500 }
    );
  }
}
