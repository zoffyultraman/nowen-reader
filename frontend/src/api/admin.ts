/**
 * 数据管理模块 API
 * 对应后端 /api/admin/storage/*
 */

export interface CacheBucket {
  key: string; // thumbnails / pages / converted / other
  label: string;
  path: string;
  sizeBytes: number;
  fileCount: number;
  dirCount: number;
  oldestAt: number;
  newestAt: number;
  exists: boolean;
}

export interface TableSize {
  name: string;
  rowCount: number;
  sizeBytes: number;
}

export interface DBInfo {
  path: string;
  mainBytes: number;
  walBytes: number;
  shmBytes: number;
  totalBytes: number;
  pageSize: number;
  pageCount: number;
  freelistCount: number;
  reclaimableMB: number;
  journalMode: string;
  integrityOK: boolean;
  tables: TableSize[];
}

export interface DiskInfo {
  path: string;
  totalBytes: number;
  freeBytes: number;
  usedBytes: number;
  available: boolean;
  usedPercent: number;
}

export interface StorageThreshold {
  cacheMaxMB?: number;
  dbMaxMB?: number;
  diskFreeMinMB?: number;
}

export interface StorageOverview {
  generatedAt: number;
  dataDir: string;
  cache: {
    totalBytes: number;
    fileCount: number;
    buckets: CacheBucket[];
  };
  database: DBInfo;
  disk: DiskInfo;
  threshold?: StorageThreshold;
  warnings?: string[];
}

async function safeJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let msg = `HTTP ${res.status}`;
    try {
      const data = await res.json();
      msg = data.error || msg;
    } catch {
      // ignore
    }
    throw new Error(msg);
  }
  return res.json() as Promise<T>;
}

export async function fetchStorageOverview(fresh = false): Promise<StorageOverview> {
  const res = await fetch(`/api/admin/storage${fresh ? "?fresh=1" : ""}`, {
    credentials: "include",
  });
  return safeJson<StorageOverview>(res);
}

export async function fetchDBInfo(): Promise<DBInfo> {
  const res = await fetch("/api/admin/storage/database", { credentials: "include" });
  return safeJson<DBInfo>(res);
}

export interface ClearCacheRequest {
  target: "thumbnails" | "pages" | "converted" | "other" | "all";
  olderThanDays?: number;
  largerThanMB?: number;
  orphanOnly?: boolean;
}

export interface ClearCacheResult {
  success: boolean;
  deleted: number;
  freedBytes: number;
}

export async function clearCacheBucket(req: ClearCacheRequest): Promise<ClearCacheResult> {
  const res = await fetch("/api/admin/storage/cache/clear", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(req),
  });
  return safeJson<ClearCacheResult>(res);
}

export interface DBOpResult {
  success: boolean;
  durationMs: number;
  beforeBytes?: number;
  afterBytes?: number;
  freedBytes?: number;
}

export async function dbCheckpoint(): Promise<DBOpResult> {
  const res = await fetch("/api/admin/storage/db/checkpoint", {
    method: "POST",
    credentials: "include",
  });
  return safeJson<DBOpResult>(res);
}

export async function dbAnalyze(): Promise<DBOpResult> {
  const res = await fetch("/api/admin/storage/db/analyze", {
    method: "POST",
    credentials: "include",
  });
  return safeJson<DBOpResult>(res);
}

export async function dbVacuum(): Promise<DBOpResult> {
  const res = await fetch("/api/admin/storage/db/vacuum", {
    method: "POST",
    credentials: "include",
  });
  return safeJson<DBOpResult>(res);
}

export interface IntegrityResult {
  success: boolean;
  ok: boolean;
  messages: string[];
  durationMs: number;
}

export async function dbIntegrityCheck(): Promise<IntegrityResult> {
  const res = await fetch("/api/admin/storage/db/integrity", {
    method: "POST",
    credentials: "include",
  });
  return safeJson<IntegrityResult>(res);
}

export async function updateStorageThreshold(t: StorageThreshold): Promise<{ success: boolean; threshold: StorageThreshold }> {
  const res = await fetch("/api/admin/storage/threshold", {
    method: "PUT",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(t),
  });
  return safeJson<{ success: boolean; threshold: StorageThreshold }>(res);
}

// ============================================================
// Helpers
// ============================================================

export function humanBytes(n: number): string {
  if (!Number.isFinite(n) || n < 0) return "—";
  if (n < 1024) return `${n} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let x = n / 1024;
  let i = 0;
  while (x >= 1024 && i < units.length - 1) {
    x /= 1024;
    i++;
  }
  return `${x.toFixed(2)} ${units[i]}`;
}

export function formatTimestamp(ts: number): string {
  if (!ts) return "—";
  const d = new Date(ts * 1000);
  return d.toLocaleString("zh-CN", { hour12: false });
}
