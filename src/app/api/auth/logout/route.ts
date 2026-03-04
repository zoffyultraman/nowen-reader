import { NextResponse } from "next/server";
import { logoutSession, SESSION_COOKIE } from "@/lib/auth";
import { cookies } from "next/headers";

export async function POST() {
  try {
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get(SESSION_COOKIE);

    if (sessionCookie?.value) {
      await logoutSession(sessionCookie.value);
    }

    cookieStore.delete(SESSION_COOKIE);

    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ error: "Logout failed" }, { status: 500 });
  }
}
