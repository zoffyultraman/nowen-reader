"use client";

import { useEffect, useRef, useCallback, useState } from "react";
import { useTranslation } from "@/lib/i18n";
import type { ReaderTheme } from "@/components/reader/ReaderToolbar";
import { useImagePreloader } from "@/hooks/useImagePreloader";

interface WebtoonViewProps {
  pages: string[];
  currentPage: number;
  onPageChange: (page: number) => void;
  onTapCenter: () => void;
  useRealData?: boolean;
  readerTheme?: ReaderTheme;
  containerWidth?: string;
  preloadCount?: number;
  /** 滚动超出边界时触发 */
  onBoundaryReached?: (direction: "next" | "prev") => void;
  /** 下一卷信息（用于底部提示） */
  nextVolumeTitle?: string;
}

/** Estimated page height for skeleton placeholders */
const ESTIMATED_PAGE_HEIGHT = 1200;
/** Number of pages to render outside viewport (buffer) */
const RENDER_BUFFER = 5;

export default function WebtoonView({
  pages,
  currentPage,
  onPageChange,
  onTapCenter,
  useRealData,
  readerTheme = "night",
  containerWidth,
  preloadCount = 5,
  onBoundaryReached,
  nextVolumeTitle,
}: WebtoonViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const pageRefs = useRef<(HTMLDivElement | null)[]>([]);
  const isScrollingRef = useRef(false);
  const scrollTimeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  // 记录上一次由滚动事件报告的页码，用于区分"外部跳转"和"滚动同步"
  const lastScrollReportedPage = useRef(currentPage);
  const t = useTranslation();

  // Track which pages are "in range" to render
  const [renderRange, setRenderRange] = useState({ start: 0, end: Math.min(RENDER_BUFFER * 2, pages.length - 1) });

  // Track loaded image heights for accurate positioning
  const [pageHeights, setPageHeights] = useState<Map<number, number>>(new Map());

  // Track which pages failed to load
  const [errorPages, setErrorPages] = useState<Set<number>>(new Set());

  // Preload images ahead of current page
  useImagePreloader(pages, currentPage, preloadCount);

  // Update render range based on scroll position
  const updateRenderRange = useCallback(() => {
    const container = containerRef.current;
    if (!container) return;

    const scrollTop = container.scrollTop;
    const viewportHeight = container.clientHeight;
    const viewCenter = scrollTop + viewportHeight / 3;

    // Determine which page is at center
    let accumulatedHeight = 0;
    let centerPage = 0;

    for (let i = 0; i < pages.length; i++) {
      const h = pageHeights.get(i) ?? ESTIMATED_PAGE_HEIGHT;
      if (accumulatedHeight + h > viewCenter) {
        centerPage = i;
        break;
      }
      accumulatedHeight += h;
      if (i === pages.length - 1) centerPage = i;
    }

    const newStart = Math.max(0, centerPage - RENDER_BUFFER);
    const newEnd = Math.min(pages.length - 1, centerPage + RENDER_BUFFER);

    setRenderRange((prev) => {
      if (prev.start !== newStart || prev.end !== newEnd) {
        return { start: newStart, end: newEnd };
      }
      return prev;
    });

    return centerPage;
  }, [pages.length, pageHeights]);

  // Scroll to current page when externally changed (e.g. progress bar drag)
  useEffect(() => {
    if (isScrollingRef.current) return;
    // 只有当页码不是由滚动事件报告的（即来自进度条等外部变更）时才滚动
    if (currentPage === lastScrollReportedPage.current) return;

    // 先确保目标页面在渲染范围内
    const newStart = Math.max(0, currentPage - RENDER_BUFFER);
    const newEnd = Math.min(pages.length - 1, currentPage + RENDER_BUFFER);
    setRenderRange({ start: newStart, end: newEnd });

    // 使用 requestAnimationFrame 等待渲染完成后再滚动
    requestAnimationFrame(() => {
      const el = pageRefs.current[currentPage];
      if (el) {
        // 使用 instant 立即跳转，避免 smooth 导致的"飞跃"效果
        el.scrollIntoView({ behavior: "instant", block: "start" });
      } else {
        // 如果目标元素还没渲染，通过累加高度计算位置直接跳转
        const container = containerRef.current;
        if (container) {
          let targetTop = 0;
          for (let i = 0; i < currentPage; i++) {
            targetTop += pageHeights.get(i) ?? ESTIMATED_PAGE_HEIGHT;
          }
          container.scrollTop = targetTop;
        }
      }
      // 更新滚动报告页码，防止滚动事件再次触发 onPageChange
      lastScrollReportedPage.current = currentPage;
    });
  }, [currentPage, pages.length, pageHeights]);

  const handleScroll = useCallback(() => {
    isScrollingRef.current = true;
    if (scrollTimeoutRef.current) clearTimeout(scrollTimeoutRef.current);
    scrollTimeoutRef.current = setTimeout(() => {
      isScrollingRef.current = false;
    }, 150);

    const centerPage = updateRenderRange();

    if (centerPage !== undefined && centerPage !== currentPage) {
      lastScrollReportedPage.current = centerPage;
      onPageChange(centerPage);
    }
  }, [currentPage, onPageChange, updateRenderRange]);

  // Record actual image height after load
  const handleImageLoad = useCallback((index: number, e: React.SyntheticEvent<HTMLImageElement>) => {
    const img = e.currentTarget;
    if (img.naturalHeight > 0) {
      setPageHeights((prev) => {
        const next = new Map(prev);
        next.set(index, img.clientHeight);
        return next;
      });
    }
  }, []);

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const width = rect.width;
    const ratio = x / width;

    if (ratio > 0.25 && ratio < 0.75) {
      onTapCenter();
    }
  };

  // Initialize render range
  useEffect(() => {
    updateRenderRange();
  }, [updateRenderRange]);

  return (
    <div
      ref={containerRef}
      className={`h-screen w-full overflow-y-auto select-none transition-colors duration-300 ${
        readerTheme === "day" ? "bg-gray-100" : "bg-black"
      }`}
      onScroll={handleScroll}
      onClick={handleClick}
    >
      <div className="mx-auto" style={containerWidth ? { width: containerWidth, maxWidth: "100%" } : { maxWidth: "48rem" }}>
        {pages.map((pageUrl, index) => {
          const isInRange = index >= renderRange.start && index <= renderRange.end;
          const estimatedHeight = pageHeights.get(index) ?? ESTIMATED_PAGE_HEIGHT;

          return (
            <div
              key={index}
              ref={(el) => {
                pageRefs.current[index] = el;
              }}
              className="relative w-full"
              style={!isInRange ? { height: estimatedHeight } : undefined}
            >
              {isInRange ? (
                useRealData ? (
                  /* eslint-disable-next-line @next/next/no-img-element */
                  errorPages.has(index) ? (
                    <div
                      className={`w-full flex items-center justify-center py-16 ${readerTheme === "day" ? "bg-gray-200" : "bg-white/5"}`}
                    >
                      <div className="flex flex-col items-center gap-2 text-center">
                        <span className="text-2xl">⚠️</span>
                        <p className={`text-xs ${readerTheme === "day" ? "text-gray-400" : "text-white/40"}`}>第 {index + 1} 页加载失败</p>
                        <button
                          onClick={(e) => { e.stopPropagation(); setErrorPages(prev => { const next = new Set(prev); next.delete(index); return next; }); }}
                          className="text-xs text-accent hover:text-accent/80"
                        >重试</button>
                      </div>
                    </div>
                  ) : (
                    <img
                      src={pageUrl}
                      alt={`Page ${index + 1}`}
                      className="w-full h-auto"
                      loading={Math.abs(index - currentPage) < 3 ? "eager" : "lazy"}
                      onLoad={(e) => handleImageLoad(index, e)}
                      onError={() => setErrorPages(prev => new Set(prev).add(index))}
                    />
                  )
                ) : (
                  <div className="relative aspect-2/3 w-full">
                    {/* Next/Image for mock data */}
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={pageUrl}
                      alt={`Page ${index + 1}`}
                      className="w-full h-auto object-contain"
                      loading={Math.abs(index - currentPage) < 3 ? "eager" : "lazy"}
                    />
                  </div>
                )
              ) : (
                /* Skeleton placeholder */
                <div
                  className={`w-full animate-pulse ${
                    readerTheme === "day" ? "bg-gray-200" : "bg-white/5"
                  }`}
                  style={{ height: estimatedHeight }}
                />
              )}
            </div>
          );
        })}

        <div className="flex items-center justify-center py-16">
          <div className="text-center">
            <p className={`text-sm ${readerTheme === "day" ? "text-gray-400" : "text-white/40"}`}>{t.reader.reachedLastPage}</p>
            {nextVolumeTitle && onBoundaryReached && (
              <button
                onClick={() => onBoundaryReached("next")}
                className="mt-4 rounded-xl bg-accent px-6 py-2.5 text-sm font-medium text-white shadow-sm shadow-accent/25 transition-all hover:bg-accent/90 hover:shadow-md"
              >
                {nextVolumeTitle} →
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
