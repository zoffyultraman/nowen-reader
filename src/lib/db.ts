import { PrismaClient } from "@/generated/prisma/client";
import { PrismaLibSql } from "@prisma/adapter-libsql";
import { createClient } from "@libsql/client";
import path from "path";

// 数据库路径 - 优先级: DATABASE_URL 环境变量 > 默认 (cwd/data.db)
function getDbUrl(): string {
  const envUrl = process.env.DATABASE_URL;
  if (envUrl) {
    if (envUrl.startsWith("file:")) return envUrl;
    return `file:${envUrl}`;
  }
  return `file:${path.join(process.cwd(), "data.db")}`;
}

// 初始化底层 LibSQL 客户端（模块级单例）
const libsqlClient = createClient({ url: getDbUrl() });
const adapter = new PrismaLibSql(libsqlClient);

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined;
};

export const prisma =
  globalForPrisma.prisma ?? new PrismaClient({ adapter });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}

// 直接通过原生 libsql 客户端注入性能 PRAGMA（libsql 本地模式默认已开启 WAL）
async function optimizeLibsql() {
  try {
    await libsqlClient.execute("PRAGMA synchronous = NORMAL;");
    await libsqlClient.execute("PRAGMA mmap_size = 268435456;");
    await libsqlClient.execute("PRAGMA cache_size = -64000;");
    await libsqlClient.execute("PRAGMA temp_store = MEMORY;");
    console.log("[DB] LibSQL 内存加速引擎已启动 🚀");
  } catch (err) {
    console.error("[DB] LibSQL 性能参数注入失败:", err);
  }
}

optimizeLibsql();
