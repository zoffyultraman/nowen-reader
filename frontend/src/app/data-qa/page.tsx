"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  RefreshCw,
  Search,
  Filter,
  AlertTriangle,
  CheckCircle2,
  Loader2,
  Shield,
  Wrench,
  Eye,
  ChevronDown,
  ChevronUp,
  X,
} from "lucide-react";
import {
  fetchSummary,
  fetchIssues,
  fetchFixPreview,
  executeFix,
  triggerPageCountRescan,
  type DataQASummary,
  type DataQAIssue,
  type DataQAFixPreviewResult,
  type DataQAFixResult,
} from "@/api/dataQa";

// ============================================================
// Severity helpers
// ============================================================

const severityColor: Record<string, string> = {
  p1: "text-red-500 bg-red-500/10 border-red-500/20",
  p2: "text-amber-500 bg-amber-500/10 border-amber-500/20",
  p3: "text-sky-500 bg-sky-500/10 border-sky-500/20",
};

function SeverityBadge({ level }: { level: string }) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${severityColor[level] ?? "text-muted bg-muted/10 border-muted/20"}`}
    >
      {level.toUpperCase()}
    </span>
  );
}

// ============================================================
// Summary cards
// ============================================================

function SummaryCards({ summary }: { summary: DataQASummary }) {
  const items = [
    { label: "Total Issues", value: summary.totalIssues, tone: summary.totalIssues > 0 ? "text-foreground" : "text-emerald-500" },
    { label: "P1", value: summary.p1, tone: summary.p1 > 0 ? "text-red-500" : "text-muted" },
    { label: "P2", value: summary.p2, tone: summary.p2 > 0 ? "text-amber-500" : "text-muted" },
    { label: "P3", value: summary.p3, tone: summary.p3 > 0 ? "text-sky-500" : "text-muted" },
    { label: "Auto-fixable", value: summary.autoFixable, tone: "text-foreground" },
  ];

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
      {items.map((item) => (
        <div key={item.label} className="surface-card rounded-xl p-4">
          <div className="text-xs text-muted">{item.label}</div>
          <div className={`mt-1 text-2xl font-semibold tracking-tight ${item.tone}`}>
            {item.value}
          </div>
        </div>
      ))}
    </div>
  );
}

// ============================================================
// Main page
// ============================================================

export default function DataQAPage() {
  const router = useRouter();
  const [summary, setSummary] = useState<DataQASummary | null>(null);
  const [issues, setIssues] = useState<DataQAIssue[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [filterType, setFilterType] = useState<string>("");
  const [filterSeverity, setFilterSeverity] = useState<string>("");
  const [filterAutoFixable, setFilterAutoFixable] = useState<string>("");
  const [searchText, setSearchText] = useState("");
  const [showFilters, setShowFilters] = useState(true);

  // Action state
  const [previewResult, setPreviewResult] = useState<DataQAFixPreviewResult | null>(null);
  const [fixResult, setFixResult] = useState<DataQAFixResult | null>(null);
  const [rescanResult, setRescanResult] = useState<{ queued: number; message: string } | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [confirmDialog, setConfirmDialog] = useState(false);
  const [toast, setToast] = useState<{ msg: string; tone: "ok" | "err" } | null>(null);

  // Auto-dismiss toast
  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(t);
  }, [toast]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [s, d] = await Promise.all([fetchSummary(), fetchIssues()]);
      setSummary(s);
      setIssues(d.issues ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Unique issue types for filter dropdown
  const issueTypes = useMemo(() => {
    const s = new Set(issues.map((i) => i.issueType));
    return Array.from(s).sort();
  }, [issues]);

  // Filtered issues
  const filtered = useMemo(() => {
    return issues.filter((i) => {
      if (filterType && i.issueType !== filterType) return false;
      if (filterSeverity && i.severity !== filterSeverity) return false;
      if (filterAutoFixable === "yes" && !i.autoFixable) return false;
      if (filterAutoFixable === "no" && i.autoFixable) return false;
      if (searchText) {
        const q = searchText.toLowerCase();
        if (
          !i.entityId.toLowerCase().includes(q) &&
          !(i.title ?? "").toLowerCase().includes(q) &&
          !i.message.toLowerCase().includes(q)
        )
          return false;
      }
      return true;
    });
  }, [issues, filterType, filterSeverity, filterAutoFixable, searchText]);

  // Fix preview
  const handlePreview = useCallback(async () => {
    setActionLoading("preview");
    setPreviewResult(null);
    setFixResult(null);
    try {
      const types = filterType ? [filterType] : undefined;
      const r = await fetchFixPreview({ issueTypes: types, fixAll: !filterType });
      setPreviewResult(r);
    } catch (e) {
      setToast({ msg: e instanceof Error ? e.message : "Preview failed", tone: "err" });
    } finally {
      setActionLoading(null);
    }
  }, [filterType]);

  // Execute fix (after confirm)
  const handleFix = useCallback(async () => {
    setConfirmDialog(false);
    setActionLoading("fix");
    setFixResult(null);
    try {
      const types = filterType ? [filterType] : undefined;
      const r = await executeFix({ issueTypes: types, fixAll: !filterType, confirm: true });
      setFixResult(r);
      setToast({ msg: `Fixed ${r.totalExecuted} issues`, tone: "ok" });
      // Refresh after fix
      await load();
    } catch (e) {
      setToast({ msg: e instanceof Error ? e.message : "Fix failed", tone: "err" });
    } finally {
      setActionLoading(null);
    }
  }, [filterType, load]);
  // PageCount rescan
  const handleRescan = useCallback(async () => {
    setActionLoading("rescan");
    setRescanResult(null);
    try {
      const r = await triggerPageCountRescan({ confirm: true, limit: 100, includeNegative: true });
      setRescanResult(r);
      setToast({ msg: `Found ${r.queued} comics needing rescan`, tone: "ok" });
    } catch (e) {
      setToast({ msg: e instanceof Error ? e.message : "Rescan failed", tone: "err" });
    } finally {
      setActionLoading(null);
    }
  }, []);


  return (
    <div className="min-h-screen bg-background pb-16">
      {/* Toast */}
      {toast && (
        <div
          className={`fixed left-1/2 top-4 z-50 -translate-x-1/2 rounded-md px-4 py-2 text-sm shadow-lg ${
            toast.tone === "ok"
              ? "bg-emerald-600 text-white"
              : "bg-red-600 text-white"
          }`}
        >
          {toast.msg}
        </div>
      )}

      {/* Confirm dialog */}
      {confirmDialog && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div className="surface-card mx-4 max-w-sm rounded-2xl p-6 shadow-xl">
            <div className="flex items-center gap-2 text-lg font-semibold">
              <AlertTriangle className="h-5 w-5 text-amber-500" />
              Confirm Fix
            </div>
            <p className="mt-3 text-sm text-muted">
              This will modify the database. Affected records will be updated or deleted.
              This action is idempotent and safe, but please ensure you have a backup.
            </p>
            <div className="mt-5 flex justify-end gap-3">
              <button
                onClick={() => setConfirmDialog(false)}
                className="motion-button rounded-lg px-4 py-2 text-sm text-muted hover:text-foreground"
              >
                Cancel
              </button>
              <button
                onClick={handleFix}
                className="motion-button rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-700"
              >
                Execute Fix
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className="sticky top-0 z-30 border-b border-border bg-background/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-3">
          <button
            onClick={() => router.back()}
            className="motion-button flex h-8 w-8 items-center justify-center rounded-lg text-muted hover:text-foreground"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-muted" />
            <h1 className="text-base font-semibold">Data QA</h1>
          </div>
          <div className="ml-auto flex items-center gap-2">
            <button
              onClick={load}
              disabled={loading}
              className="motion-button flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-muted hover:text-foreground"
            >
              <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </button>
          </div>
        </div>
      </div>

      <div className="mx-auto max-w-6xl space-y-6 px-4 pt-6">
        {/* Error */}
        {error && (
          <div className="rounded-xl border border-red-500/20 bg-red-500/5 p-4 text-sm text-red-400">
            {error}
          </div>
        )}

        {/* Summary */}
        {summary && <SummaryCards summary={summary} />}

        {/* Action bar */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={handlePreview}
            disabled={actionLoading !== null}
            className="motion-button flex items-center gap-1.5 rounded-lg border border-border px-4 py-2 text-sm font-medium hover:bg-card-hover"
          >
            {actionLoading === "preview" ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Eye className="h-3.5 w-3.5" />
            )}
            Dry-run Preview
          </button>
          <button
            onClick={() => setConfirmDialog(true)}
            disabled={actionLoading !== null}
            className="motion-button flex items-center gap-1.5 rounded-lg bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-700"
          >
            {actionLoading === "fix" ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <Wrench className="h-3.5 w-3.5" />
            )}
            Execute Fix
          </button>
          <button
            onClick={handleRescan}
            disabled={actionLoading !== null}
            className="motion-button flex items-center gap-1.5 rounded-lg border border-border px-4 py-2 text-sm font-medium hover:bg-card-hover"
          >
            {actionLoading === "rescan" ? (
              <Loader2 className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <RefreshCw className="h-3.5 w-3.5" />
            )}
            PageCount Rescan
          </button>
          <div className="ml-auto text-xs text-muted">
            {filtered.length} / {issues.length} issues
          </div>
        </div>

        {/* Filters */}
        <div className="surface-card rounded-xl p-4">
          <button
            onClick={() => setShowFilters((v) => !v)}
            className="flex w-full items-center gap-2 text-sm font-medium text-muted hover:text-foreground"
          >
            <Filter className="h-3.5 w-3.5" />
            Filters
            {showFilters ? <ChevronUp className="ml-auto h-3.5 w-3.5" /> : <ChevronDown className="ml-auto h-3.5 w-3.5" />}
          </button>
          {showFilters && (
            <div className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-4">
              {/* Search */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted" />
                <input
                  type="text"
                  placeholder="Search entity/message..."
                  value={searchText}
                  onChange={(e) => setSearchText(e.target.value)}
                  className="w-full rounded-lg border border-border bg-background py-2 pl-9 pr-3 text-sm outline-none focus:border-primary"
                />
              </div>
              {/* Issue type */}
              <select
                value={filterType}
                onChange={(e) => setFilterType(e.target.value)}
                className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary"
              >
                <option value="">All types</option>
                {issueTypes.map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </select>
              {/* Severity */}
              <select
                value={filterSeverity}
                onChange={(e) => setFilterSeverity(e.target.value)}
                className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary"
              >
                <option value="">All severities</option>
                <option value="p1">P1</option>
                <option value="p2">P2</option>
                <option value="p3">P3</option>
              </select>
              {/* Auto-fixable */}
              <select
                value={filterAutoFixable}
                onChange={(e) => setFilterAutoFixable(e.target.value)}
                className="rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:border-primary"
              >
                <option value="">All</option>
                <option value="yes">Auto-fixable</option>
                <option value="no">Not auto-fixable</option>
              </select>
            </div>
          )}
        </div>

        {/* Preview result */}
        {previewResult && (
          <div className="surface-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-medium">Dry-run Preview</div>
              <button onClick={() => setPreviewResult(null)} className="text-muted hover:text-foreground">
                <X className="h-4 w-4" />
              </button>
            </div>
            <div className="mt-2 text-xs text-muted">
              {previewResult.totalPlanned} fixes planned, {previewResult.skipped.length} skipped
            </div>
            {previewResult.plans.length > 0 && (
              <div className="mt-3 max-h-60 space-y-2 overflow-y-auto">
                {previewResult.plans.map((p, i) => (
                  <div key={i} className="flex items-start gap-2 rounded-lg border border-border p-2 text-xs">
                    <Wrench className="mt-0.5 h-3 w-3 flex-shrink-0 text-amber-500" />
                    <div>
                      <span className="font-medium">{p.action}</span>
                      <span className="ml-2 text-muted">{p.entityId}</span>
                      {p.currentVal && p.expectedVal && (
                        <span className="ml-2 text-muted">
                          {p.currentVal} → {p.expectedVal}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
            {previewResult.skipped.length > 0 && (
              <div className="mt-2 text-xs text-muted">
                Skipped: {previewResult.skipped.map((s) => s.reason).join("; ")}
              </div>
            )}
          </div>
        )}

        {/* Fix result */}
        {fixResult && (
          <div className="surface-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-medium">
                <CheckCircle2 className="h-4 w-4 text-emerald-500" />
                Fix Result
              </div>
              <button onClick={() => setFixResult(null)} className="text-muted hover:text-foreground">
                <X className="h-4 w-4" />
              </button>
            </div>
            <div className="mt-2 text-xs text-muted">
              {fixResult.totalExecuted} executed, {fixResult.skipped.length} skipped, {fixResult.errors.length} errors
            </div>
            {fixResult.executed.length > 0 && (
              <div className="mt-3 max-h-60 space-y-2 overflow-y-auto">
                {fixResult.executed.map((e, i) => (
                  <div key={i} className="flex items-start gap-2 rounded-lg border border-emerald-500/20 bg-emerald-500/5 p-2 text-xs">
                    <CheckCircle2 className="mt-0.5 h-3 w-3 flex-shrink-0 text-emerald-500" />
                    <div>
                      <span className="font-medium">{e.action}</span>
                      <span className="ml-2 text-muted">{e.entityId}</span>
                      <span className="ml-2 text-muted">{e.before} → {e.after}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
            {fixResult.errors.length > 0 && (
              <div className="mt-3 max-h-40 space-y-2 overflow-y-auto">
                {fixResult.errors.map((e, i) => (
                  <div key={i} className="flex items-start gap-2 rounded-lg border border-red-500/20 bg-red-500/5 p-2 text-xs">
                    <AlertTriangle className="mt-0.5 h-3 w-3 flex-shrink-0 text-red-500" />
                    <div>
                      <span className="font-medium">{e.action}</span>
                      <span className="ml-2 text-muted">{e.entityId}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

{/* PageCount Rescan result */}
        {rescanResult && (
          <div className="surface-card rounded-xl p-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-medium">PageCount Rescan</div>
              <button onClick={() => setRescanResult(null)} className="text-muted hover:text-foreground">
                <X className="h-4 w-4" />
              </button>
            </div>
            <div className="mt-2 text-xs text-muted">{rescanResult.message}</div>
            {rescanResult.queued > 0 && (
              <div className="mt-1 text-xs text-amber-500">
                {rescanResult.queued} comics queued for background scanner
              </div>
            )}
          </div>
        )}

        {/* Issue list */}
        <div className="space-y-2">
          {loading && issues.length === 0 ? (
            <div className="flex items-center justify-center py-12 text-muted">
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Scanning...
            </div>
          ) : filtered.length === 0 ? (
            <div className="surface-card flex flex-col items-center justify-center rounded-xl py-12">
              <CheckCircle2 className="h-8 w-8 text-emerald-500" />
              <div className="mt-2 text-sm text-muted">No issues found</div>
            </div>
          ) : (
            filtered.map((issue) => (
              <IssueRow key={issue.id} issue={issue} />
            ))
          )}
        </div>
      </div>
    </div>
  );
}

// ============================================================
// Issue row
// ============================================================

function IssueRow({ issue }: { issue: DataQAIssue }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="surface-card rounded-xl p-4 transition-colors hover:bg-card-hover">
      <div
        className="flex cursor-pointer items-start gap-3"
        onClick={() => setExpanded((v) => !v)}
      >
        <div className="mt-0.5 flex-shrink-0">
          {issue.autoFixable ? (
            <Wrench className="h-4 w-4 text-amber-500" />
          ) : (
            <AlertTriangle className="h-4 w-4 text-muted" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <SeverityBadge level={issue.severity} />
            <span className="text-xs font-medium text-foreground">{issue.issueType}</span>
            <span className="text-xs text-muted">{issue.entityType}</span>
            {issue.autoFixable && (
              <span className="text-xs text-amber-500">auto-fix</span>
            )}
          </div>
          <div className="mt-1 truncate text-sm text-muted">{issue.entityId}</div>
          {issue.title && (
            <div className="mt-0.5 text-sm font-medium">{issue.title}</div>
          )}
        </div>
        {expanded ? (
          <ChevronUp className="h-4 w-4 flex-shrink-0 text-muted" />
        ) : (
          <ChevronDown className="h-4 w-4 flex-shrink-0 text-muted" />
        )}
      </div>
      {expanded && (
        <div className="mt-3 space-y-2 border-t border-border pt-3 pl-7 text-sm text-muted">
          <div>{issue.message}</div>
          {(issue.currentVal || issue.expectedVal) && (
            <div className="flex gap-4 text-xs">
              {issue.currentVal && (
                <span>
                  Current: <span className="font-mono text-foreground">{issue.currentVal}</span>
                </span>
              )}
              {issue.expectedVal && (
                <span>
                  Expected: <span className="font-mono text-foreground">{issue.expectedVal}</span>
                </span>
              )}
            </div>
          )}
          <div className="text-xs text-muted/60">ID: {issue.id}</div>
        </div>
      )}
    </div>
  );
}
