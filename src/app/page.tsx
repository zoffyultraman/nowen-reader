"use client";

import { useState, useMemo, useRef, useCallback } from "react";
import Navbar from "@/components/Navbar";
import ComicCard from "@/components/ComicCard";
import TagFilter from "@/components/TagFilter";
import StatsBar from "@/components/StatsBar";
import GroupFilter from "@/components/GroupFilter";
import BatchToolbar from "@/components/BatchToolbar";
import { RecommendationStrip } from "@/components/Recommendations";
import { mockComics } from "@/data/mock-comics";
import {
  useComics,
  uploadComics,
  ApiComic,
  batchOperation,
  updateSortOrders,
  useGroups,
} from "@/hooks/useComics";
import { Comic } from "@/types/comic";
import { useTranslation } from "@/lib/i18n";

// Convert API comic to display comic
function apiToComic(api: ApiComic): Comic {
  return {
    id: api.id,
    title: api.title,
    coverUrl: api.coverUrl,
    tags: api.tags.map((t) => t.name),
    pageCount: api.pageCount,
    progress:
      api.pageCount > 0
        ? Math.round((api.lastReadPage / api.pageCount) * 100)
        : 0,
    lastRead: api.lastReadAt || undefined,
    isFavorite: api.isFavorite,
    rating: api.rating ?? undefined,
    lastReadPage: api.lastReadPage,
    sortOrder: api.sortOrder,
    groupName: api.groupName,
    totalReadTime: api.totalReadTime,
  };
}

export default function Home() {
  const t = useTranslation();
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");
  const [uploading, setUploading] = useState(false);
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [sortBy, setSortBy] = useState<string>("title");
  const [sortOrder, setSortOrder] = useState<string>("asc");
  const [selectedGroup, setSelectedGroup] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Batch selection
  const [batchMode, setBatchMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  // Drag state
  const [dragId, setDragId] = useState<string | null>(null);
  const [dragOverId, setDragOverId] = useState<string | null>(null);

  // Fetch real comics from API
  const { comics: apiComics, loading, refetch } = useComics();
  const { groups, refetch: refetchGroups } = useGroups();

  // Use real comics if available, else fallback to mock
  const useRealData = apiComics.length > 0;
  const displayComics: Comic[] = useMemo(() => {
    if (useRealData) {
      return apiComics.map(apiToComic);
    }
    return mockComics;
  }, [apiComics, useRealData]);

  // Extract all unique tags
  const allTags = useMemo(() => {
    const tagSet = new Set<string>();
    displayComics.forEach((comic) =>
      comic.tags.forEach((tag) => tagSet.add(tag))
    );
    return Array.from(tagSet).sort();
  }, [displayComics]);

  // Filter comics
  const filteredComics = useMemo(() => {
    return displayComics.filter((comic) => {
      const matchesSearch =
        searchQuery === "" ||
        comic.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        comic.tags.some((tag) =>
          tag.toLowerCase().includes(searchQuery.toLowerCase())
        ) ||
        comic.author?.toLowerCase().includes(searchQuery.toLowerCase());

      const matchesTags =
        selectedTags.length === 0 ||
        selectedTags.some((tag) => comic.tags.includes(tag));

      const matchesFavorite = !favoritesOnly || comic.isFavorite;

      const matchesGroup =
        selectedGroup === null ||
        (selectedGroup === "" ? !comic.groupName || comic.groupName === "" : comic.groupName === selectedGroup);

      return matchesSearch && matchesTags && matchesFavorite && matchesGroup;
    });
  }, [displayComics, searchQuery, selectedTags, favoritesOnly, selectedGroup]);

  // Sort comics
  const sortedComics = useMemo(() => {
    const sorted = [...filteredComics];
    sorted.sort((a, b) => {
      let cmp = 0;
      switch (sortBy) {
        case "title":
          cmp = a.title.localeCompare(b.title);
          break;
        case "lastReadAt":
          cmp =
            (a.lastRead || "").localeCompare(b.lastRead || "") ||
            a.title.localeCompare(b.title);
          break;
        case "rating":
          cmp = (a.rating || 0) - (b.rating || 0);
          break;
        case "custom":
          cmp = (a.sortOrder || 0) - (b.sortOrder || 0);
          break;
        default:
          cmp = a.title.localeCompare(b.title);
      }
      return sortOrder === "desc" ? -cmp : cmp;
    });
    return sorted;
  }, [filteredComics, sortBy, sortOrder]);

  const handleTagToggle = (tag: string) => {
    setSelectedTags((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]
    );
  };

  // Upload handler
  const handleUpload = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const handleFileChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = e.target.files;
      if (!files || files.length === 0) return;

      setUploading(true);
      try {
        const result = await uploadComics(files);
        if (result.success) {
          await refetch();
          refetchGroups();
        }
        alert(result.message);
      } catch {
        alert(t.home.uploadFailed);
      } finally {
        setUploading(false);
        if (fileInputRef.current) fileInputRef.current.value = "";
      }
    },
    [refetch, refetchGroups]
  );

  // Batch selection handlers
  const toggleSelect = useCallback((id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const handleSelectAll = useCallback(() => {
    if (selectedIds.size === sortedComics.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(sortedComics.map((c) => c.id)));
    }
  }, [sortedComics, selectedIds.size]);

  const exitBatchMode = useCallback(() => {
    setBatchMode(false);
    setSelectedIds(new Set());
  }, []);

  const handleBatchDelete = useCallback(async () => {
    const ids = Array.from(selectedIds);
    await batchOperation("delete", ids);
    exitBatchMode();
    await refetch();
    refetchGroups();
  }, [selectedIds, exitBatchMode, refetch, refetchGroups]);

  const handleBatchFavorite = useCallback(async () => {
    await batchOperation("favorite", Array.from(selectedIds), { isFavorite: true });
    exitBatchMode();
    await refetch();
  }, [selectedIds, exitBatchMode, refetch]);

  const handleBatchUnfavorite = useCallback(async () => {
    await batchOperation("unfavorite", Array.from(selectedIds));
    exitBatchMode();
    await refetch();
  }, [selectedIds, exitBatchMode, refetch]);

  const handleBatchAddTags = useCallback(
    async (tags: string[]) => {
      await batchOperation("addTags", Array.from(selectedIds), { tags });
      exitBatchMode();
      await refetch();
    },
    [selectedIds, exitBatchMode, refetch]
  );

  const handleBatchSetGroup = useCallback(
    async (groupName: string) => {
      await batchOperation("setGroup", Array.from(selectedIds), { groupName });
      exitBatchMode();
      await refetch();
      refetchGroups();
    },
    [selectedIds, exitBatchMode, refetch, refetchGroups]
  );

  // Drag & Drop handlers
  const handleDragStart = useCallback((id: string) => {
    setDragId(id);
  }, []);

  const handleDragOver = useCallback((id: string) => {
    setDragOverId(id);
  }, []);

  const handleDragEnd = useCallback(async () => {
    if (!dragId || !dragOverId || dragId === dragOverId) {
      setDragId(null);
      setDragOverId(null);
      return;
    }

    const items = [...sortedComics];
    const fromIndex = items.findIndex((c) => c.id === dragId);
    const toIndex = items.findIndex((c) => c.id === dragOverId);

    if (fromIndex === -1 || toIndex === -1) {
      setDragId(null);
      setDragOverId(null);
      return;
    }

    // Reorder
    const [moved] = items.splice(fromIndex, 1);
    items.splice(toIndex, 0, moved);

    // Build new sort orders
    const orders = items.map((c, i) => ({ id: c.id, sortOrder: i }));

    // Switch to custom sort to see the effect
    setSortBy("custom");
    setSortOrder("asc");

    setDragId(null);
    setDragOverId(null);

    await updateSortOrders(orders);
    await refetch();
  }, [dragId, dragOverId, sortedComics, refetch]);

  return (
    <div className="min-h-screen bg-background">
      {/* Hidden file input for upload */}
      <input
        ref={fileInputRef}
        type="file"
        multiple
        accept=".zip,.cbz,.cbr,.rar,.7z,.cb7,.pdf"
        className="hidden"
        onChange={handleFileChange}
      />

      <Navbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        viewMode={viewMode}
        onViewModeChange={setViewMode}
        onUpload={handleUpload}
        uploading={uploading}
        batchMode={batchMode}
        onToggleBatchMode={() => {
          if (batchMode) exitBatchMode();
          else setBatchMode(true);
        }}
        onSelectAll={handleSelectAll}
        allSelected={selectedIds.size === sortedComics.length && sortedComics.length > 0}
      />

      {/* Main Content */}
      <main className={`mx-auto max-w-[1800px] px-6 pt-24 ${batchMode ? "pb-32" : "pb-12"}`}>
        {/* Data Source Indicator */}
        {!loading && !useRealData && (
          <div className="mb-4 flex items-center gap-2 rounded-lg border border-amber-500/20 bg-amber-500/5 px-4 py-3">
            <span className="text-sm text-amber-400">
              {t.home.mockDataNotice}{" "}
              <code className="rounded bg-amber-500/10 px-1.5 py-0.5 font-mono text-xs">
                .zip
              </code>{" "}
              /{" "}
              <code className="rounded bg-amber-500/10 px-1.5 py-0.5 font-mono text-xs">
                .cbz
              </code>{" "}
              {t.home.mockDataNotice2}{" "}
              <code className="rounded bg-amber-500/10 px-1.5 py-0.5 font-mono text-xs">
                comics/
              </code>{" "}
              {t.home.mockDataNotice3}
            </span>
          </div>
        )}

        {/* Loading */}
        {loading && (
          <div className="flex items-center justify-center py-32">
            <div className="h-8 w-8 animate-spin rounded-full border-2 border-muted border-t-accent" />
          </div>
        )}

        {!loading && (
          <>
            {/* Recommendations */}
            {useRealData && <RecommendationStrip />}

            {/* Stats + Sort Controls */}
            <div className="flex flex-wrap items-center justify-between gap-4">
              <StatsBar
                totalComics={displayComics.length}
                filteredCount={sortedComics.length}
              />

              {/* Sort & Filter Controls */}
              <div className="flex items-center gap-3">
                {/* Favorites toggle */}
                <button
                  onClick={() => setFavoritesOnly(!favoritesOnly)}
                  className={`flex h-8 items-center gap-1.5 rounded-lg px-3 text-xs font-medium transition-all ${
                    favoritesOnly
                      ? "bg-rose-500/20 text-rose-400"
                      : "bg-card text-muted hover:text-foreground"
                  }`}
                >
                  <span>{favoritesOnly ? "♥" : "♡"}</span>
                  <span>{t.home.favorites}</span>
                </button>

                {/* Sort selector */}
                <select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value)}
                  className="h-8 rounded-lg bg-card px-2 text-xs text-foreground outline-none"
                >
                  <option value="title">{t.home.sortByTitle}</option>
                  <option value="lastReadAt">{t.home.sortByLastRead}</option>
                  <option value="rating">{t.home.sortByRating}</option>
                  <option value="custom">{t.home.sortByCustom}</option>
                </select>

                <button
                  onClick={() =>
                    setSortOrder((o) => (o === "asc" ? "desc" : "asc"))
                  }
                  className="flex h-8 w-8 items-center justify-center rounded-lg bg-card text-muted transition-colors hover:text-foreground"
                  title={sortOrder === "asc" ? t.home.ascending : t.home.descending}
                >
                  {sortOrder === "asc" ? "↑" : "↓"}
                </button>
              </div>
            </div>

            {/* Group Filter */}
            {groups.length > 0 && (
              <div className="mt-4">
                <GroupFilter
                  groups={groups}
                  selectedGroup={selectedGroup}
                  onGroupSelect={setSelectedGroup}
                />
              </div>
            )}

            {/* Tag Filter */}
            {allTags.length > 0 && (
              <div className="mt-4 mb-8">
                <TagFilter
                  allTags={allTags}
                  selectedTags={selectedTags}
                  onTagToggle={handleTagToggle}
                  onClearAll={() => setSelectedTags([])}
                />
              </div>
            )}

            {/* Comics Grid */}
            {sortedComics.length > 0 ? (
              <div
                className={
                  viewMode === "grid"
                    ? "grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6"
                    : "grid grid-cols-1 gap-3"
                }
              >
                {sortedComics.map((comic) => (
                  <ComicCard
                    key={comic.id}
                    comic={comic}
                    isReal={useRealData}
                    viewMode={viewMode}
                    batchMode={batchMode}
                    isSelected={selectedIds.has(comic.id)}
                    onSelect={() => toggleSelect(comic.id)}
                    draggable={sortBy === "custom" && !batchMode}
                    onDragStart={() => handleDragStart(comic.id)}
                    onDragOver={() => handleDragOver(comic.id)}
                    onDragEnd={handleDragEnd}
                    isDragOver={dragOverId === comic.id}
                  />
                ))}
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-32 text-center">
                <div className="mb-4 flex h-20 w-20 items-center justify-center rounded-2xl bg-card">
                  <span className="text-4xl">📚</span>
                </div>
                <h3 className="mb-2 text-lg font-medium text-foreground/80">
                  {displayComics.length === 0
                    ? t.home.emptyLibrary
                    : t.home.noMatchingComics}
                </h3>
                <p className="max-w-sm text-sm text-muted">
                  {displayComics.length === 0
                    ? t.home.emptyLibraryHint
                    : t.home.noMatchingHint}
                </p>
              </div>
            )}
          </>
        )}
      </main>

      {/* Batch Toolbar */}
      {batchMode && selectedIds.size > 0 && (
        <BatchToolbar
          selectedCount={selectedIds.size}
          onCancel={exitBatchMode}
          onDelete={handleBatchDelete}
          onFavorite={handleBatchFavorite}
          onUnfavorite={handleBatchUnfavorite}
          onAddTags={handleBatchAddTags}
          onSetGroup={handleBatchSetGroup}
        />
      )}
    </div>
  );
}
