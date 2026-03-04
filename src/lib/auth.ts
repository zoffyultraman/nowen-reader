import { prisma } from "./db";
import bcrypt from "bcryptjs";
import { v4 as uuidv4 } from "uuid";
import { cookies } from "next/headers";

const SESSION_COOKIE = "nowen_session";
const SESSION_MAX_AGE = 30 * 24 * 60 * 60 * 1000; // 30 days

export interface AuthUser {
  id: string;
  username: string;
  nickname: string;
  role: string;
}

/**
 * Register a new user
 */
export async function registerUser(
  username: string,
  password: string,
  nickname?: string
): Promise<AuthUser> {
  const existing = await prisma.user.findUnique({ where: { username } });
  if (existing) {
    throw new Error("Username already exists");
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  // First user is admin
  const userCount = await prisma.user.count();
  const role = userCount === 0 ? "admin" : "user";

  const user = await prisma.user.create({
    data: {
      username,
      password: hashedPassword,
      nickname: nickname || username,
      role,
    },
  });

  return {
    id: user.id,
    username: user.username,
    nickname: user.nickname,
    role: user.role,
  };
}

/**
 * Login and create session
 */
export async function loginUser(
  username: string,
  password: string
): Promise<{ user: AuthUser; token: string }> {
  const user = await prisma.user.findUnique({ where: { username } });
  if (!user) {
    throw new Error("Invalid username or password");
  }

  const valid = await bcrypt.compare(password, user.password);
  if (!valid) {
    throw new Error("Invalid username or password");
  }

  // Create session
  const token = uuidv4();
  const expiresAt = new Date(Date.now() + SESSION_MAX_AGE);

  await prisma.userSession.create({
    data: {
      id: token,
      userId: user.id,
      expiresAt,
    },
  });

  return {
    user: {
      id: user.id,
      username: user.username,
      nickname: user.nickname,
      role: user.role,
    },
    token,
  };
}

/**
 * Logout - delete session
 */
export async function logoutSession(token: string) {
  try {
    await prisma.userSession.delete({ where: { id: token } });
  } catch {
    // Session may not exist
  }
}

/**
 * Validate session token and return user
 */
export async function validateSession(token: string): Promise<AuthUser | null> {
  const session = await prisma.userSession.findUnique({
    where: { id: token },
    include: { user: true },
  });

  if (!session) return null;

  // Check expiration
  if (session.expiresAt < new Date()) {
    await prisma.userSession.delete({ where: { id: token } });
    return null;
  }

  return {
    id: session.user.id,
    username: session.user.username,
    nickname: session.user.nickname,
    role: session.user.role,
  };
}

/**
 * Get current user from request cookies
 */
export async function getCurrentUser(): Promise<AuthUser | null> {
  try {
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get(SESSION_COOKIE);
    if (!sessionCookie?.value) return null;
    return validateSession(sessionCookie.value);
  } catch {
    return null;
  }
}

/**
 * Check if any users exist (for initial setup)
 */
export async function hasAnyUsers(): Promise<boolean> {
  const count = await prisma.user.count();
  return count > 0;
}

/**
 * Change password
 */
export async function changePassword(
  userId: string,
  oldPassword: string,
  newPassword: string
) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new Error("User not found");

  const valid = await bcrypt.compare(oldPassword, user.password);
  if (!valid) throw new Error("Current password is incorrect");

  const hashedPassword = await bcrypt.hash(newPassword, 10);
  await prisma.user.update({
    where: { id: userId },
    data: { password: hashedPassword },
  });
}

/**
 * Update user profile
 */
export async function updateUserProfile(
  userId: string,
  data: { nickname?: string }
) {
  return prisma.user.update({
    where: { id: userId },
    data,
  });
}

/**
 * List all users (admin only)
 */
export async function listUsers() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      username: true,
      nickname: true,
      role: true,
      createdAt: true,
    },
    orderBy: { createdAt: "asc" },
  });
  return users;
}

/**
 * Delete user (admin only)
 */
export async function deleteUser(userId: string) {
  return prisma.user.delete({ where: { id: userId } });
}

/**
 * Clean up expired sessions
 */
export async function cleanExpiredSessions() {
  await prisma.userSession.deleteMany({
    where: { expiresAt: { lt: new Date() } },
  });
}

export { SESSION_COOKIE, SESSION_MAX_AGE };
