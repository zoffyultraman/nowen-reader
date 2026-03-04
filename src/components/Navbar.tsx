"use client";

import { useState } from "react";
import Link from "next/link";
import {
  Search,
  Upload,
  BookMarked,
  LayoutGrid,
  List,
  Loader2,
  CheckSquare,
  BarChart3,
  CheckCheck,
} from "lucide-react";
import { useTranslation } from "@/lib/i18n";
import LanguageSwitcher from "@/components/LanguageSwitcher";
import { UserMenu } from "@/components/UserMenu";

interface NavbarProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  viewMode: "grid" | "list";
  onViewModeChange: (mode: "grid" | "list") => void;
  onUpload?: () => void;
  uploading?: boolean;
  batchMode?: boolean;
  onToggleBatchMode?: () => void;
  onSelectAll?: () => void;
  allSelected?: boolean;
}

export default function Navbar({
  searchQuery,
  onSearchChange,
  viewMode,
  onViewModeChange,
  onUpload,
  uploading,
  batchMode,
  onToggleBatchMode,
  onSelectAll,
  allSelected,
}: NavbarProps) {
  const [isSearchFocused, setIsSearchFocused] = useState(false);
  const t = useTranslation();

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-border/50 bg-background/70 backdrop-blur-xl backdrop-saturate-150">
      <div className="mx-auto flex h-16 max-w-[1800px] items-center justify-between px-6">
        {/* Logo */}
        <div className="flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent">
            <BookMarked className="h-5 w-5 text-white" />
          </div>
          <span className="text-lg font-bold tracking-tight text-foreground">
            NowenReader
          </span>
        </div>

        {/* Search Bar */}
        <div className="flex flex-1 items-center justify-center px-8">
          <div
            className={`relative flex w-full max-w-md items-center transition-all duration-300 ${
              isSearchFocused ? "max-w-lg" : ""
            }`}
          >
            <Search className="absolute left-3 h-4 w-4 text-muted" />
            <input
              type="text"
              placeholder={t.navbar.searchPlaceholder}
              value={searchQuery}
              onChange={(e) => onSearchChange(e.target.value)}
              onFocus={() => setIsSearchFocused(true)}
              onBlur={() => setIsSearchFocused(false)}
              className="h-10 w-full rounded-xl border border-border/60 bg-card/50 pl-10 pr-4 text-sm text-foreground placeholder:text-muted/60 outline-none transition-all duration-300 focus:border-accent/50 focus:bg-card focus:ring-2 focus:ring-accent/20"
            />
          </div>
        </div>

        {/* Right Actions */}
        <div className="flex items-center gap-2">
          {/* Batch Mode Toggle */}
          {batchMode && (
            <button
              onClick={onSelectAll}
              className={`flex h-9 items-center gap-1.5 rounded-xl px-3 text-xs font-medium transition-all ${
                allSelected
                  ? "bg-accent/20 text-accent"
                  : "border border-border/60 text-muted hover:text-foreground"
              }`}
              title={t.navbar.selectAll}
            >
              <CheckCheck className="h-4 w-4" />
              <span className="hidden sm:inline">{t.navbar.selectAll}</span>
            </button>
          )}

          <button
            onClick={onToggleBatchMode}
            className={`flex h-9 items-center gap-1.5 rounded-xl px-3 text-xs font-medium transition-all ${
              batchMode
                ? "bg-accent text-white"
                : "border border-border/60 text-muted hover:text-foreground"
            }`}
            title={t.navbar.batch}
          >
            <CheckSquare className="h-4 w-4" />
            <span className="hidden sm:inline">{batchMode ? t.navbar.exitBatch : t.navbar.batch}</span>
          </button>

          {/* Stats */}
          <Link
            href="/stats"
            className="flex h-9 w-9 items-center justify-center rounded-xl border border-border/60 text-muted transition-colors duration-200 hover:border-border hover:text-foreground"
            title={t.navbar.stats}
          >
            <BarChart3 className="h-4 w-4" />
          </Link>

          {/* View Toggle */}
          <div className="flex items-center rounded-lg border border-border/60 bg-card/50 p-0.5">
            <button
              onClick={() => onViewModeChange("grid")}
              className={`flex h-8 w-8 items-center justify-center rounded-md transition-all duration-200 ${
                viewMode === "grid"
                  ? "bg-accent text-white shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              <LayoutGrid className="h-4 w-4" />
            </button>
            <button
              onClick={() => onViewModeChange("list")}
              className={`flex h-8 w-8 items-center justify-center rounded-md transition-all duration-200 ${
                viewMode === "list"
                  ? "bg-accent text-white shadow-sm"
                  : "text-muted hover:text-foreground"
              }`}
            >
              <List className="h-4 w-4" />
            </button>
          </div>

          {/* Upload */}
          <button
            onClick={onUpload}
            disabled={uploading}
            className="flex h-9 items-center gap-2 rounded-xl bg-accent px-4 text-sm font-medium text-white transition-all duration-200 hover:bg-accent-hover hover:shadow-lg hover:shadow-accent/25 disabled:opacity-50"
          >
            {uploading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Upload className="h-4 w-4" />
            )}
            <span className="hidden sm:inline">{uploading ? t.navbar.uploading : t.navbar.upload}</span>
          </button>

          {/* Language Switcher */}
          <LanguageSwitcher />

          {/* User Menu */}
          <UserMenu />
        </div>
      </div>
    </nav>
  );
}
