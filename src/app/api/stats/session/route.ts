import { NextRequest, NextResponse } from "next/server";
import { startReadingSession, endReadingSession } from "@/lib/comic-service";

// Start a reading session
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { comicId, startPage } = body;

    if (!comicId) {
      return NextResponse.json({ error: "comicId required" }, { status: 400 });
    }

    const session = await startReadingSession(comicId, startPage || 0);
    return NextResponse.json({ sessionId: session.id });
  } catch (err) {
    console.error("Failed to start session:", err);
    return NextResponse.json(
      { error: "Failed to start session" },
      { status: 500 }
    );
  }
}

// End a reading session
export async function PUT(request: NextRequest) {
  try {
    const body = await request.json();
    const { sessionId, endPage, duration } = body;

    if (!sessionId || typeof duration !== "number") {
      return NextResponse.json(
        { error: "sessionId and duration required" },
        { status: 400 }
      );
    }

    await endReadingSession(sessionId, endPage || 0, duration);
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Failed to end session:", err);
    return NextResponse.json(
      { error: "Failed to end session" },
      { status: 500 }
    );
  }
}
