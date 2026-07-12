import type { Comic } from "@/types/comic";

export interface SeriesSummary {
  id: string;
  libraryId: string;
  rootRelativePath: string;
  title: string;
  sortTitle: string;
  coverComicId: string;
  coverUrl: string;
  itemCount: number;
  sectionCount: number;
  completedItemCount: number;
  totalReadTime: number;
  fileSize: number;
  lastReadAt?: string | null;
  isFavorite: boolean;
  manualLocked: boolean;
  canManage?: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface SeriesItem {
  comic: Comic & {
    filename?: string;
    type?: string;
    readingStatus?: string;
  };
  sectionId?: string;
  sortIndex: number;
  displayLabel: string;
}

export interface SeriesSection {
  id: string;
  title: string;
  relativePath: string;
  kind: "season" | "arc" | "special" | string;
  seasonNumber?: number;
  sortIndex: number;
  manualLocked: boolean;
  items: SeriesItem[];
}

export interface SeriesDetail {
  series: SeriesSummary;
  sections: SeriesSection[];
  unsectioned: SeriesItem[];
}
