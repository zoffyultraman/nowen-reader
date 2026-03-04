// Generate mock page image URLs for each comic
// Using picsum.photos with different seeds for variety

export function getMockPages(comicId: string, count: number = 20): string[] {
  return Array.from({ length: count }, (_, i) => {
    return `https://picsum.photos/seed/${comicId}-page-${i}/800/1200`;
  });
}

// Pre-defined page counts per comic
export const comicPageCounts: Record<string, number> = {
  "1": 24,
  "2": 18,
  "3": 32,
  "4": 15,
  "5": 28,
  "6": 20,
  "7": 17,
  "8": 13,
  "9": 26,
  "10": 40,
  "11": 10,
  "12": 11,
};
