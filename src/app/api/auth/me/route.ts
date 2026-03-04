import { NextResponse } from "next/server";
import { getCurrentUser, hasAnyUsers } from "@/lib/auth";

export async function GET() {
  try {
    const hasUsers = await hasAnyUsers();
    if (!hasUsers) {
      return NextResponse.json({
        user: null,
        needsSetup: true,
      });
    }

    const user = await getCurrentUser();

    return NextResponse.json({
      user,
      needsSetup: false,
    });
  } catch {
    return NextResponse.json({ user: null, needsSetup: false });
  }
}
