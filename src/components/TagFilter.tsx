"use client";

import { Tag } from "lucide-react";
import { useTranslation } from "@/lib/i18n";

interface TagFilterProps {
  allTags: string[];
  selectedTags: string[];
  onTagToggle: (tag: string) => void;
  onClearAll: () => void;
}

const tagColorMap: Record<string, string> = {
  Action: "border-red-500/30 text-red-400 hover:bg-red-500/10",
  Romance: "border-pink-500/30 text-pink-400 hover:bg-pink-500/10",
  Comedy: "border-amber-500/30 text-amber-400 hover:bg-amber-500/10",
  Fantasy: "border-indigo-500/30 text-indigo-400 hover:bg-indigo-500/10",
  Horror: "border-purple-500/30 text-purple-400 hover:bg-purple-500/10",
  "Sci-Fi": "border-cyan-500/30 text-cyan-400 hover:bg-cyan-500/10",
  Drama: "border-green-500/30 text-green-400 hover:bg-green-500/10",
  "Slice of Life": "border-orange-500/30 text-orange-400 hover:bg-orange-500/10",
  Adventure: "border-blue-500/30 text-blue-400 hover:bg-blue-500/10",
  Mystery: "border-rose-500/30 text-rose-400 hover:bg-rose-500/10",
};

const tagActiveColorMap: Record<string, string> = {
  Action: "bg-red-500/20 border-red-500/50 text-red-300",
  Romance: "bg-pink-500/20 border-pink-500/50 text-pink-300",
  Comedy: "bg-amber-500/20 border-amber-500/50 text-amber-300",
  Fantasy: "bg-indigo-500/20 border-indigo-500/50 text-indigo-300",
  Horror: "bg-purple-500/20 border-purple-500/50 text-purple-300",
  "Sci-Fi": "bg-cyan-500/20 border-cyan-500/50 text-cyan-300",
  Drama: "bg-green-500/20 border-green-500/50 text-green-300",
  "Slice of Life": "bg-orange-500/20 border-orange-500/50 text-orange-300",
  Adventure: "bg-blue-500/20 border-blue-500/50 text-blue-300",
  Mystery: "bg-rose-500/20 border-rose-500/50 text-rose-300",
};

export default function TagFilter({
  allTags,
  selectedTags,
  onTagToggle,
  onClearAll,
}: TagFilterProps) {
  const t = useTranslation();

  return (
    <div className="flex items-center gap-3 overflow-x-auto pb-2 scrollbar-hide">
      <div className="flex items-center gap-1.5 text-muted">
        <Tag className="h-3.5 w-3.5" />
        <span className="text-xs font-medium whitespace-nowrap">{t.tagFilter.label}</span>
      </div>

      <div className="flex items-center gap-2">
        {/* All Tag */}
        <button
          onClick={onClearAll}
          className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-all duration-200 ${
            selectedTags.length === 0
              ? "bg-accent/20 border-accent/50 text-accent"
              : "border-border/60 text-muted hover:text-foreground hover:border-border"
          }`}
        >
          {t.common.all}
        </button>

        {allTags.map((tag) => {
          const isActive = selectedTags.includes(tag);
          return (
            <button
              key={tag}
              onClick={() => onTagToggle(tag)}
              className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-all duration-200 whitespace-nowrap ${
                isActive
                  ? tagActiveColorMap[tag] || "bg-zinc-500/20 border-zinc-500/50 text-zinc-300"
                  : tagColorMap[tag] || "border-border/60 text-muted hover:text-foreground"
              }`}
            >
              {tag}
            </button>
          );
        })}
      </div>
    </div>
  );
}
