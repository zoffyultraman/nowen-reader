import { NextRequest, NextResponse } from "next/server";
import { generateRootCatalog, getBaseUrl, OPDS_MIME } from "@/lib/opds";

export async function GET(request: NextRequest) {
  const baseUrl = getBaseUrl(request.url);
  const xml = generateRootCatalog(baseUrl);

  return new NextResponse(xml, {
    status: 200,
    headers: {
      "Content-Type": OPDS_MIME,
    },
  });
}
