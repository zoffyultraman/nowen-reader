import { NextResponse } from "next/server";
import { getAllTags } from "@/lib/comic-service";

export async function GET() {
  try {
    const tags = await getAllTags();
    return NextResponse.json({ tags });
  } catch (err) {
    console.error("Failed to fetch tags:", err);
    return NextResponse.json(
      { error: "Failed to fetch tags" },
      { status: 500 }
    );
  }
}
