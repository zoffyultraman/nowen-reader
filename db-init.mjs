#!/usr/bin/env node
/**
 * Database initialization script for production Docker image.
 * Uses @libsql directly to create tables (no prisma CLI needed).
 * Safe to run multiple times - uses CREATE TABLE IF NOT EXISTS.
 */
import { createClient } from "@libsql/client";

const dbUrl = process.env.DATABASE_URL || "file:/data/nowen-reader.db";
// @libsql/client expects url without "file:" prefix for local files
const url = dbUrl.startsWith("file:") ? dbUrl : `file:${dbUrl}`;

const client = createClient({ url });

const statements = [
  // User
  `CREATE TABLE IF NOT EXISTS "User" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "username" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "nickname" TEXT NOT NULL DEFAULT '',
    "role" TEXT NOT NULL DEFAULT 'user',
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "User_username_key" ON "User"("username")`,
  `CREATE INDEX IF NOT EXISTS "User_username_idx" ON "User"("username")`,

  // UserSession
  `CREATE TABLE IF NOT EXISTS "UserSession" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "userId" TEXT NOT NULL,
    "expiresAt" DATETIME NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "UserSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE
  )`,
  `CREATE INDEX IF NOT EXISTS "UserSession_userId_idx" ON "UserSession"("userId")`,
  `CREATE INDEX IF NOT EXISTS "UserSession_expiresAt_idx" ON "UserSession"("expiresAt")`,

  // Comic
  `CREATE TABLE IF NOT EXISTS "Comic" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "filename" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "pageCount" INTEGER NOT NULL DEFAULT 0,
    "fileSize" INTEGER NOT NULL DEFAULT 0,
    "addedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "lastReadPage" INTEGER NOT NULL DEFAULT 0,
    "lastReadAt" DATETIME,
    "isFavorite" BOOLEAN NOT NULL DEFAULT false,
    "rating" INTEGER,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "totalReadTime" INTEGER NOT NULL DEFAULT 0,
    "author" TEXT NOT NULL DEFAULT '',
    "publisher" TEXT NOT NULL DEFAULT '',
    "year" INTEGER,
    "description" TEXT NOT NULL DEFAULT '',
    "language" TEXT NOT NULL DEFAULT '',
    "seriesName" TEXT NOT NULL DEFAULT '',
    "seriesIndex" INTEGER,
    "genre" TEXT NOT NULL DEFAULT '',
    "metadataSource" TEXT NOT NULL DEFAULT '',
    "coverImageUrl" TEXT NOT NULL DEFAULT ''
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "Comic_filename_key" ON "Comic"("filename")`,
  `CREATE INDEX IF NOT EXISTS "Comic_title_idx" ON "Comic"("title")`,
  `CREATE INDEX IF NOT EXISTS "Comic_isFavorite_idx" ON "Comic"("isFavorite")`,
  `CREATE INDEX IF NOT EXISTS "Comic_lastReadAt_idx" ON "Comic"("lastReadAt")`,
  `CREATE INDEX IF NOT EXISTS "Comic_sortOrder_idx" ON "Comic"("sortOrder")`,
  `CREATE INDEX IF NOT EXISTS "Comic_author_idx" ON "Comic"("author")`,
  `CREATE INDEX IF NOT EXISTS "Comic_seriesName_idx" ON "Comic"("seriesName")`,

  // Tag
  `CREATE TABLE IF NOT EXISTS "Tag" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "color" TEXT NOT NULL DEFAULT 'default'
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "Tag_name_key" ON "Tag"("name")`,
  `CREATE INDEX IF NOT EXISTS "Tag_name_idx" ON "Tag"("name")`,

  // ComicTag
  `CREATE TABLE IF NOT EXISTS "ComicTag" (
    "comicId" TEXT NOT NULL,
    "tagId" INTEGER NOT NULL,
    PRIMARY KEY ("comicId", "tagId"),
    CONSTRAINT "ComicTag_comicId_fkey" FOREIGN KEY ("comicId") REFERENCES "Comic" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ComicTag_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "Tag" ("id") ON DELETE CASCADE ON UPDATE CASCADE
  )`,

  // Category
  `CREATE TABLE IF NOT EXISTS "Category" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "icon" TEXT NOT NULL DEFAULT '📚',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "Category_name_key" ON "Category"("name")`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "Category_slug_key" ON "Category"("slug")`,
  `CREATE INDEX IF NOT EXISTS "Category_slug_idx" ON "Category"("slug")`,
  `CREATE INDEX IF NOT EXISTS "Category_sortOrder_idx" ON "Category"("sortOrder")`,

  // ComicCategory
  `CREATE TABLE IF NOT EXISTS "ComicCategory" (
    "comicId" TEXT NOT NULL,
    "categoryId" INTEGER NOT NULL,
    PRIMARY KEY ("comicId", "categoryId"),
    CONSTRAINT "ComicCategory_comicId_fkey" FOREIGN KEY ("comicId") REFERENCES "Comic" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ComicCategory_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "Category" ("id") ON DELETE CASCADE ON UPDATE CASCADE
  )`,

  // ReadingSession
  `CREATE TABLE IF NOT EXISTS "ReadingSession" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "comicId" TEXT NOT NULL,
    "startedAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" DATETIME,
    "duration" INTEGER NOT NULL DEFAULT 0,
    "startPage" INTEGER NOT NULL DEFAULT 0,
    "endPage" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "ReadingSession_comicId_fkey" FOREIGN KEY ("comicId") REFERENCES "Comic" ("id") ON DELETE CASCADE ON UPDATE CASCADE
  )`,
  `CREATE INDEX IF NOT EXISTS "ReadingSession_comicId_idx" ON "ReadingSession"("comicId")`,
  `CREATE INDEX IF NOT EXISTS "ReadingSession_startedAt_idx" ON "ReadingSession"("startedAt")`,
];

async function init() {
  console.log("[db-init] Initializing database at:", url);
  for (const sql of statements) {
    try {
      await client.execute(sql);
    } catch (err) {
      // Log but continue - table may already exist with slightly different schema
      console.warn("[db-init] Warning:", err.message?.slice(0, 120));
    }
  }
  console.log("[db-init] Database schema ready.");
  client.close();
}

init().catch((err) => {
  console.error("[db-init] Fatal error:", err);
  process.exit(1);
});
