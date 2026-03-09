import { NextResponse } from "next/server";
import { loginUser, SESSION_COOKIE, SESSION_MAX_AGE } from "@/lib/auth";
import { cookies } from "next/headers";
import { isRequestSecure } from "@/lib/auth-utils";

export async function POST(request: Request) {
  try {
    const { username, password } = await request.json();

    if (!username || !password) {
      return NextResponse.json(
        { error: "Username and password are required" },
        { status: 400 }
      );
    }

    const { user, token } = await loginUser(username, password);

    const cookieStore = await cookies();
    cookieStore.set(SESSION_COOKIE, token, {
      httpOnly: true,
      secure: isRequestSecure(request),
      sameSite: "lax",
      maxAge: SESSION_MAX_AGE / 1000,
      path: "/",
    });

    return NextResponse.json({ user });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Login failed";
    return NextResponse.json({ error: message }, { status: 401 });
  }
}
