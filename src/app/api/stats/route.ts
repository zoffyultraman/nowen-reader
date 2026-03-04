import { NextResponse } from "next/server";
import { getReadingStats } from "@/lib/comic-service";

export async function GET() {
  try {
    const stats = await getReadingStats();
    return NextResponse.json(stats);
  } catch (err) {
    console.error("Failed to fetch stats:", err);
    return NextResponse.json(
      { error: "Failed to fetch reading stats" },
      { status: 500 }
    );
  }
}
