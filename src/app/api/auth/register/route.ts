import { NextResponse } from "next/server";
import { registerUser, loginUser, SESSION_COOKIE, SESSION_MAX_AGE } from "@/lib/auth";
import { cookies } from "next/headers";
import { isRequestSecure } from "@/lib/auth-utils";

export async function POST(request: Request) {
  try {
    const { username, password, nickname } = await request.json();

    if (!username || !password) {
      return NextResponse.json(
        { error: "Username and password are required" },
        { status: 400 }
      );
    }

    if (username.length < 3 || username.length > 32) {
      return NextResponse.json(
        { error: "Username must be 3-32 characters" },
        { status: 400 }
      );
    }

    if (password.length < 6) {
      return NextResponse.json(
        { error: "Password must be at least 6 characters" },
        { status: 400 }
      );
    }

    const user = await registerUser(username, password, nickname);

    // Auto-login after registration
    const { token } = await loginUser(username, password);

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
    const message = err instanceof Error ? err.message : "Registration failed";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
