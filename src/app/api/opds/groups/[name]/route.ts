import { NextRequest, NextResponse } from "next/server";
import { generateAcquisitionFeed, getBaseUrl, OPDS_ACQUISITION_MIME } from "@/lib/opds";
import { prisma } from "@/lib/db";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ name: string }> }
) {
  try {
    const { name } = await params;
    const groupName = decodeURIComponent(name);

    const comics = await prisma.comic.findMany({
      where: { groupName },
      orderBy: { title: "asc" },
      include: {
        tags: { include: { tag: true } },
      },
    });

    const opdsComics = comics.map((c) => ({
      id: c.id,
      title: c.title,
      author: c.author || undefined,
      description: c.description || undefined,
      language: c.language || undefined,
      genre: c.genre || undefined,
      publisher: c.publisher || undefined,
      year: c.year || undefined,
      pageCount: c.pageCount,
      addedAt: c.addedAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
      tags: c.tags.map((ct) => ({ name: ct.tag.name })),
      filename: c.filename,
    }));

    const baseUrl = getBaseUrl(request.url);
    const xml = generateAcquisitionFeed(
      baseUrl,
      `Group: ${groupName}`,
      `${baseUrl}/api/opds/groups/${encodeURIComponent(groupName)}`,
      opdsComics,
      `/api/opds/groups/${encodeURIComponent(groupName)}`
    );

    return new NextResponse(xml, {
      status: 200,
      headers: { "Content-Type": OPDS_ACQUISITION_MIME },
    });
  } catch (err) {
    console.error("OPDS group error:", err);
    return NextResponse.json({ error: "Failed to generate feed" }, { status: 500 });
  }
}
