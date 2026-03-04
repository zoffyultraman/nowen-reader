import { NextRequest, NextResponse } from "next/server";
import { updateSortOrders } from "@/lib/comic-service";

export async function PUT(request: NextRequest) {
  try {
    const body = await request.json();
    const { orders } = body;

    if (!Array.isArray(orders)) {
      return NextResponse.json(
        { error: "orders array required" },
        { status: 400 }
      );
    }

    await updateSortOrders(orders);
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error("Reorder failed:", err);
    return NextResponse.json({ error: "Reorder failed" }, { status: 500 });
  }
}
