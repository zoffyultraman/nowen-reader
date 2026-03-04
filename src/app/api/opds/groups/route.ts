import { NextRequest, NextResponse } from "next/server";
import { generateGroupsFeed, getBaseUrl, OPDS_MIME } from "@/lib/opds";
import { getAllGroups } from "@/lib/comic-service";

export async function GET(request: NextRequest) {
  try {
    const groups = await getAllGroups();

    const baseUrl = getBaseUrl(request.url);
    const xml = generateGroupsFeed(baseUrl, groups);

    return new NextResponse(xml, {
      status: 200,
      headers: { "Content-Type": OPDS_MIME },
    });
  } catch (err) {
    console.error("OPDS groups error:", err);
    return NextResponse.json({ error: "Failed to generate feed" }, { status: 500 });
  }
}
