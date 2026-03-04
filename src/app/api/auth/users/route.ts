import { NextResponse } from "next/server";
import { getCurrentUser, listUsers, deleteUser, changePassword, updateUserProfile } from "@/lib/auth";

export async function GET() {
  try {
    const currentUser = await getCurrentUser();
    if (!currentUser || currentUser.role !== "admin") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
    }

    const users = await listUsers();
    return NextResponse.json({ users });
  } catch {
    return NextResponse.json({ error: "Failed to list users" }, { status: 500 });
  }
}

export async function PUT(request: Request) {
  try {
    const currentUser = await getCurrentUser();
    if (!currentUser) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { action, userId, oldPassword, newPassword, nickname } = await request.json();

    if (action === "changePassword") {
      const targetId = userId || currentUser.id;
      // Non-admin can only change own password
      if (targetId !== currentUser.id && currentUser.role !== "admin") {
        return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
      }
      await changePassword(targetId, oldPassword, newPassword);
      return NextResponse.json({ success: true });
    }

    if (action === "updateProfile") {
      const targetId = userId || currentUser.id;
      if (targetId !== currentUser.id && currentUser.role !== "admin") {
        return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
      }
      await updateUserProfile(targetId, { nickname });
      return NextResponse.json({ success: true });
    }

    return NextResponse.json({ error: "Invalid action" }, { status: 400 });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Operation failed";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}

export async function DELETE(request: Request) {
  try {
    const currentUser = await getCurrentUser();
    if (!currentUser || currentUser.role !== "admin") {
      return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
    }

    const { userId } = await request.json();
    if (userId === currentUser.id) {
      return NextResponse.json({ error: "Cannot delete yourself" }, { status: 400 });
    }

    await deleteUser(userId);
    return NextResponse.json({ success: true });
  } catch {
    return NextResponse.json({ error: "Failed to delete user" }, { status: 500 });
  }
}
