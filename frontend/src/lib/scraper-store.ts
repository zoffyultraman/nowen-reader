/**
 * 全局刮削状态管理 (模块级单例)
 *
 * SSE 连接和进度状态保存在模块作用域中，
 * 页面组件卸载/重新挂载不会丢失正在进行的刮削进度。
 */

/* ── 类型 ── */
export interface ProgressItem {
  type: string;
  current: number;
  total: number;
  comicId: string;
  filename: string;
  step?: string;
  status?: string;
  source?: string;
  message?: string;
  matchTitle?: string;
  resultsCount?: number;
  parsed?: {
    title?: string;
    author?: string;
    year?: number;
    language?: string;
    genre?: string;
    group?: string;
    tags?: string;
  };
}

export interface CompletedItem extends ProgressItem {
  id: string;
}

export interface BatchDone {
  type: string;
  total: number;
  success: number;
  failed: number;
}

export interface MetadataStats {
  total: number;
  withMetadata: number;
  missing: number;
}

export type BatchMode = "standard" | "ai";
export type ScrapeScope = "missing" | "all";

export type MetaFilter = "all" | "with" | "missing";
export type ActiveTab = "scrape" | "library";

export interface LibraryItemTag {
  name: string;
  color: string;
}

export interface LibraryItem {
  id: string;
  title: string;
  filename: string;
  author: string;
  genre: string;
  description: string;
  year: number | null;
  metadataSource: string;
  hasMetadata: boolean;
  contentType: string;
  tags: LibraryItemTag[];
}

export interface ScraperState {
  // 统计
  stats: MetadataStats | null;
  statsLoading: boolean;
  // 运行状态
  batchRunning: boolean;
  batchMode: BatchMode;
  scrapeScope: ScrapeScope;
  updateTitle: boolean;
  // 进度
  currentProgress: ProgressItem | null;
  batchDone: BatchDone | null;
  completedItems: CompletedItem[];
  showResults: boolean;
  // 书库管理
  activeTab: ActiveTab;
  libraryItems: LibraryItem[];
  libraryLoading: boolean;
  librarySearch: string;
  libraryMetaFilter: MetaFilter;
  libraryContentType: string; // "" | "comic" | "novel"
  libraryPage: number;
  libraryPageSize: number;
  libraryTotalPages: number;
  libraryTotal: number;
  selectedIds: Set<string>;
  // 详情面板
  focusedItemId: string | null;
}

/* ── 模块级状态 ── */
let state: ScraperState = {
  stats: null,
  statsLoading: false,
  batchRunning: false,
  batchMode: "standard",
  scrapeScope: "missing",
  updateTitle: false,
  currentProgress: null,
  batchDone: null,
  completedItems: [],
  showResults: true,
  // 书库管理
  activeTab: "scrape",
  libraryItems: [],
  libraryLoading: false,
  librarySearch: "",
  libraryMetaFilter: "all",
  libraryContentType: "",
  libraryPage: 1,
  libraryPageSize: 20,
  libraryTotalPages: 1,
  libraryTotal: 0,
  selectedIds: new Set(),
  // 详情面板
  focusedItemId: null,
};

let abortController: AbortController | null = null;
const listeners = new Set<() => void>();

/* ── 订阅机制 ── */
function notify() {
  // 创建新的 state 引用以触发 useSyncExternalStore 重渲染
  state = { ...state };
  listeners.forEach((fn) => fn());
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function getSnapshot(): ScraperState {
  return state;
}

/* ── Actions ── */

export function setBatchMode(mode: BatchMode) {
  if (state.batchRunning) return;
  state.batchMode = mode;
  notify();
}

export function setScrapeScope(scope: ScrapeScope) {
  if (state.batchRunning) return;
  state.scrapeScope = scope;
  notify();
}

export function setShowResults(show: boolean) {
  state.showResults = show;
  notify();
}

export function setUpdateTitle(enabled: boolean) {
  if (state.batchRunning) return;
  state.updateTitle = enabled;
  notify();
}

export async function loadStats() {
  state.statsLoading = true;
  notify();
  try {
    const res = await fetch("/api/metadata/stats");
    if (res.ok) {
      state.stats = await res.json();
    }
  } catch {
    // ignore
  } finally {
    state.statsLoading = false;
    notify();
  }
}

export async function startBatch() {
  if (state.batchRunning) return;

  state.batchRunning = true;
  state.currentProgress = null;
  state.batchDone = null;
  state.completedItems = [];
  state.showResults = true;
  notify();

  const abort = new AbortController();
  abortController = abort;

  const endpoint =
    state.batchMode === "ai" ? "/api/metadata/ai-batch" : "/api/metadata/batch";
  const lang = navigator.language.startsWith("zh") ? "zh" : "en";

  try {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mode: state.scrapeScope, lang, updateTitle: state.updateTitle }),
      signal: abort.signal,
    });

    const reader = res.body?.getReader();
    if (!reader) return;
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        try {
          const data = JSON.parse(line.slice(6));
          if (data.type === "complete") {
            state.batchDone = data;
            notify();
          } else if (data.type === "progress") {
            state.currentProgress = data;
            // 只有最终状态才加入完成列表
            if (
              data.status === "success" ||
              data.status === "failed" ||
              data.status === "skipped"
            ) {
              state.completedItems = [
                ...state.completedItems,
                { ...data, id: `${data.comicId}-${Date.now()}` },
              ];
            }
            notify();
          }
        } catch {
          /* skip */
        }
      }
    }
  } catch (err) {
    if ((err as Error).name !== "AbortError") {
      state.batchDone = { type: "complete", success: 0, failed: 0, total: 0 };
      notify();
    }
  } finally {
    state.batchRunning = false;
    abortController = null;
    notify();
    // 刷新统计
    loadStats();
  }
}

export function cancelBatch() {
  abortController?.abort();
  state.batchRunning = false;
  notify();
}

/* ── Tab 切换 ── */
export function setActiveTab(tab: ActiveTab) {
  state.activeTab = tab;
  notify();
}

/* ── 书库管理 Actions ── */

export function setLibrarySearch(search: string) {
  state.librarySearch = search;
  state.libraryPage = 1;
  notify();
}

export function setLibraryMetaFilter(filter: MetaFilter) {
  state.libraryMetaFilter = filter;
  state.libraryPage = 1;
  notify();
}

export function setLibraryContentType(ct: string) {
  state.libraryContentType = ct;
  state.libraryPage = 1;
  notify();
}

export function setLibraryPage(page: number) {
  state.libraryPage = page;
  notify();
}

export function setLibraryPageSize(size: number) {
  state.libraryPageSize = size;
  state.libraryPage = 1; // 切换每页条数时回到第一页
  notify();
}

export function setFocusedItem(id: string | null) {
  state.focusedItemId = id;
  notify();
}

export function toggleSelectItem(id: string) {
  const next = new Set(state.selectedIds);
  if (next.has(id)) next.delete(id);
  else next.add(id);
  state.selectedIds = next;
  notify();
}

export function selectAllVisible() {
  const next = new Set(state.selectedIds);
  for (const item of state.libraryItems) {
    next.add(item.id);
  }
  state.selectedIds = next;
  notify();
}

export function deselectAll() {
  state.selectedIds = new Set();
  notify();
}

export async function loadLibrary() {
  state.libraryLoading = true;
  notify();
  try {
    const params = new URLSearchParams({
      page: String(state.libraryPage),
      pageSize: String(state.libraryPageSize),
      metaFilter: state.libraryMetaFilter,
    });
    if (state.librarySearch) params.set("search", state.librarySearch);
    if (state.libraryContentType) params.set("contentType", state.libraryContentType);

    const res = await fetch(`/api/metadata/library?${params}`);
    if (res.ok) {
      const data = await res.json();
      state.libraryItems = data.items || [];
      state.libraryTotal = data.total || 0;
      state.libraryTotalPages = data.totalPages || 1;
    }
  } catch {
    // ignore
  } finally {
    state.libraryLoading = false;
    notify();
  }
}

export async function startBatchSelected() {
  if (state.batchRunning || state.selectedIds.size === 0) return;

  state.activeTab = "scrape";
  state.batchRunning = true;
  state.currentProgress = null;
  state.batchDone = null;
  state.completedItems = [];
  state.showResults = true;
  notify();

  const abort = new AbortController();
  abortController = abort;
  const lang = navigator.language.startsWith("zh") ? "zh" : "en";

  try {
    const res = await fetch("/api/metadata/batch-selected", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        comicIds: Array.from(state.selectedIds),
        lang,
        updateTitle: state.updateTitle,
        mode: state.batchMode,
      }),
      signal: abort.signal,
    });

    const reader = res.body?.getReader();
    if (!reader) return;
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        try {
          const data = JSON.parse(line.slice(6));
          if (data.type === "complete") {
            state.batchDone = data;
            notify();
          } else if (data.type === "progress") {
            state.currentProgress = data;
            if (data.status === "success" || data.status === "failed" || data.status === "skipped") {
              state.completedItems = [
                ...state.completedItems,
                { ...data, id: `${data.comicId}-${Date.now()}` },
              ];
            }
            notify();
          }
        } catch { /* skip */ }
      }
    }
  } catch (err) {
    if ((err as Error).name !== "AbortError") {
      state.batchDone = { type: "complete", success: 0, failed: 0, total: 0 };
      notify();
    }
  } finally {
    state.batchRunning = false;
    abortController = null;
    state.selectedIds = new Set();
    notify();
    loadStats();
    loadLibrary();
  }
}

export async function clearSelectedMetadata() {
  if (state.selectedIds.size === 0) return;
  try {
    const res = await fetch("/api/metadata/clear", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ comicIds: Array.from(state.selectedIds) }),
    });
    if (res.ok) {
      state.selectedIds = new Set();
      notify();
      loadLibrary();
      loadStats();
    }
  } catch {
    // ignore
  }
}
