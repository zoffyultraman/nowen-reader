"use client";

import { FolderOpen } from "lucide-react";
import { useTranslation } from "@/lib/i18n";

interface GroupFilterProps {
  groups: { name: string; count: number }[];
  selectedGroup: string | null; // null = all
  onGroupSelect: (group: string | null) => void;
}

export default function GroupFilter({
  groups,
  selectedGroup,
  onGroupSelect,
}: GroupFilterProps) {
  const t = useTranslation();

  if (groups.length === 0) return null;

  return (
    <div className="flex items-center gap-3 overflow-x-auto pb-2 scrollbar-hide">
      <div className="flex items-center gap-1.5 text-muted">
        <FolderOpen className="h-3.5 w-3.5" />
        <span className="text-xs font-medium whitespace-nowrap">{t.groupFilter.label}</span>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={() => onGroupSelect(null)}
          className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-all duration-200 ${
            selectedGroup === null
              ? "bg-accent/20 border-accent/50 text-accent"
              : "border-border/60 text-muted hover:text-foreground hover:border-border"
          }`}
        >
          {t.common.all}
        </button>

        <button
          onClick={() => onGroupSelect("")}
          className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-all duration-200 whitespace-nowrap ${
            selectedGroup === ""
              ? "bg-zinc-500/20 border-zinc-500/50 text-zinc-300"
              : "border-border/60 text-muted hover:text-foreground hover:border-border"
          }`}
        >
          {t.groupFilter.ungrouped}
        </button>

        {groups.map((group) => (
          <button
            key={group.name}
            onClick={() => onGroupSelect(group.name)}
            className={`rounded-lg border px-3 py-1.5 text-xs font-medium transition-all duration-200 whitespace-nowrap ${
              selectedGroup === group.name
                ? "bg-accent/20 border-accent/50 text-accent"
                : "border-border/60 text-muted hover:text-foreground hover:border-border"
            }`}
          >
            {group.name}
            <span className="ml-1 text-[10px] opacity-60">{group.count}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
