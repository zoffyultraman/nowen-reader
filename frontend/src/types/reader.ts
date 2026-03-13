// Comic reading modes (no "text" — novels use a dedicated reader)
export type ComicReadingMode = "single" | "double" | "webtoon";

// Legacy alias — kept for backward compatibility
export type ReadingMode = ComicReadingMode | "text";

export type ReadingDirection = "ltr" | "rtl"; // left-to-right or right-to-left (manga style)

export interface ReaderSettings {
  mode: ComicReadingMode;
  direction: ReadingDirection;
  fitMode: "width" | "height" | "contain";
  showPageNumber: boolean;
}

export const defaultReaderSettings: ReaderSettings = {
  mode: "single",
  direction: "ltr",
  fitMode: "contain",
  showPageNumber: true,
};
