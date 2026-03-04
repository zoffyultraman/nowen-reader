import { NextRequest, NextResponse } from "next/server";
import { syncComicsToDatabase, getAllComics } from "@/lib/comic-service";

export async function GET(request: NextRequest) {
  try {
    // Sync filesystem with database first
    await syncComicsToDatabase();

    // Parse query params
    const { searchParams } = new URL(request.url);
    const search = searchParams.get("search") || undefined;
    const tagsParam = searchParams.get("tags");
    const tags = tagsParam ? tagsParam.split(",").filter(Boolean) : undefined;
    const favoritesOnly = searchParams.get("favorites") === "true";
    const sortBy = (searchParams.get("sortBy") as "title" | "addedAt" | "lastReadAt" | "rating") || "title";
    const sortOrder = (searchParams.get("sortOrder") as "asc" | "desc") || "asc";

    const comics = await getAllComics({
      search,
      tags,
      favoritesOnly,
      sortBy,
      sortOrder,
    });

    return NextResponse.json({ comics, total: comics.length });
  } catch (err) {
    console.error("Failed to fetch comics:", err);
    return NextResponse.json(
      { error: "Failed to fetch comics" },
      { status: 500 }
    );
  }
}
