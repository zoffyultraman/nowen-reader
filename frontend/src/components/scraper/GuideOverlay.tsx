"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { ChevronLeft, ChevronRight, Lightbulb } from "lucide-react";
import { GUIDE_STEPS, nextGuideStep, prevGuideStep, skipGuide, finishGuide } from "@/lib/scraper-store";

export function GuideOverlay({
  scraperT,
  currentStep,
}: {
  scraperT: Record<string, string>;
  currentStep: number;
}) {
  const step = GUIDE_STEPS[currentStep];
  const [targetRect, setTargetRect] = useState<DOMRect | null>(null);
  const totalSteps = GUIDE_STEPS.length;
  const maskId = useRef(`guide-mask-${Math.random().toString(36).slice(2, 8)}`).current;

  // 计算目标元素位置的函数
  const updateTargetRect = useCallback(() => {
    if (!step) { setTargetRect(null); return; }
    const el = document.querySelector(step.targetSelector);
    if (el) {
      // 检查元素是否实际可见（排除 display:none / visibility:hidden / 零尺寸）
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        setTargetRect(rect);
      } else {
        setTargetRect(null);
      }
    } else {
      setTargetRect(null);
    }
  }, [step]);

  // 当步骤切换时：滚动到目标元素并计算位置
  useEffect(() => {
    if (!step) return;
    const el = document.querySelector(step.targetSelector);
    if (el) {
      const rect = el.getBoundingClientRect();
      // 仅在目标元素不在视口内时才滚动
      const inView = rect.top >= 0 && rect.bottom <= window.innerHeight;
      if (!inView) {
        el.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }
      // 延迟计算位置（等待 scroll 完成）
      const timer = setTimeout(updateTargetRect, 350);
      return () => clearTimeout(timer);
    } else {
      // 目标元素不存在 → 自动跳过该步骤
      setTargetRect(null);
      const skipTimer = setTimeout(() => {
        if (currentStep < totalSteps - 1) {
          nextGuideStep();
        } else {
          finishGuide();
        }
      }, 100);
      return () => clearTimeout(skipTimer);
    }
  }, [currentStep, step, totalSteps, updateTargetRect]);

  // 监听窗口 resize 和 scroll 以实时刷新遮罩位置
  useEffect(() => {
    if (!step) return;

    const handleUpdate = () => { updateTargetRect(); };
    window.addEventListener("resize", handleUpdate);
    window.addEventListener("scroll", handleUpdate, true); // true 捕获阶段，兼容内部滚动容器

    return () => {
      window.removeEventListener("resize", handleUpdate);
      window.removeEventListener("scroll", handleUpdate, true);
    };
  }, [step, updateTargetRect]);

  if (!step) return null;

  const stepLabel = (scraperT.guideStepOf || "步骤 {current}/{total}")
    .replace("{current}", String(currentStep + 1))
    .replace("{total}", String(totalSteps));

  // 计算弹窗位置（增加视口边界安全检测）
  const getTooltipStyle = (): React.CSSProperties => {
    if (!targetRect) return { top: "50%", left: "50%", transform: "translate(-50%, -50%)", position: "fixed", zIndex: 10002 };

    const gap = 16;
    const tooltipW = 360;
    const tooltipH = 260; // 预估高度
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const style: React.CSSProperties = { position: "fixed", zIndex: 10002 };

    switch (step.placement) {
      case "bottom": {
        const top = targetRect.bottom + gap;
        style.top = top + tooltipH > vh ? Math.max(16, targetRect.top - tooltipH - gap) : top;
        style.left = Math.max(16, Math.min(targetRect.left, vw - tooltipW - 16));
        break;
      }
      case "top": {
        const bottom = vh - targetRect.top + gap;
        if (targetRect.top - gap - tooltipH < 0) {
          // 上方空间不足，改到下方
          style.top = targetRect.bottom + gap;
        } else {
          style.bottom = bottom;
        }
        style.left = Math.max(16, Math.min(targetRect.left, vw - tooltipW - 16));
        break;
      }
      case "left": {
        style.top = Math.max(16, Math.min(targetRect.top, vh - tooltipH - 16));
        const right = vw - targetRect.left + gap;
        if (targetRect.left - gap - tooltipW < 0) {
          // 左侧空间不足，改到右侧
          style.left = targetRect.right + gap;
        } else {
          style.right = right;
        }
        break;
      }
      case "right": {
        style.top = Math.max(16, Math.min(targetRect.top, vh - tooltipH - 16));
        const left = targetRect.right + gap;
        if (left + tooltipW > vw) {
          // 右侧空间不足，改到左侧
          style.right = vw - targetRect.left + gap;
        } else {
          style.left = left;
        }
        break;
      }
    }
    return style;
  };

  return (
    <div className="fixed inset-0 z-[10000]" style={{ pointerEvents: "auto" }}>
      {/* 暗色遮罩（排除高亮区域）— 点击遮罩区域不做任何操作 */}
      <svg
        className="absolute inset-0 w-full h-full"
        style={{ zIndex: 10000, pointerEvents: "auto" }}
        onClick={(e) => e.stopPropagation()}
      >
        <defs>
          <mask id={maskId}>
            <rect width="100%" height="100%" fill="white" />
            {targetRect && (
              <rect
                x={targetRect.left - 6}
                y={targetRect.top - 6}
                width={targetRect.width + 12}
                height={targetRect.height + 12}
                rx="12"
                fill="black"
              />
            )}
          </mask>
        </defs>
        <rect
          width="100%"
          height="100%"
          fill="rgba(0,0,0,0.6)"
          mask={`url(#${maskId})`}
        />
      </svg>

      {/* 高亮区域的透明交互层 — 允许用户点击高亮区域 */}
      {targetRect && (
        <div
          className="fixed"
          style={{
            zIndex: 10001,
            top: targetRect.top - 6,
            left: targetRect.left - 6,
            width: targetRect.width + 12,
            height: targetRect.height + 12,
            pointerEvents: "auto",
          }}
        />
      )}

      {/* 高亮边框 */}
      {targetRect && (
        <div
          className="fixed border-2 border-accent rounded-xl pointer-events-none"
          style={{
            zIndex: 10001,
            top: targetRect.top - 6,
            left: targetRect.left - 6,
            width: targetRect.width + 12,
            height: targetRect.height + 12,
            boxShadow: "0 0 0 4px rgba(var(--accent-rgb, 99 102 241) / 0.3), 0 0 20px rgba(var(--accent-rgb, 99 102 241) / 0.2)",
            animation: "pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
          }}
        />
      )}

      {/* 提示卡片 */}
      <div
        style={getTooltipStyle()}
        className="w-[360px] rounded-2xl bg-card border border-border/60 shadow-2xl p-5 space-y-3 animate-in fade-in slide-in-from-bottom-3 duration-300"
      >
        {/* 步骤指示器 */}
        <div className="flex items-center justify-between">
          <span className="text-[10px] font-medium text-accent bg-accent/10 rounded-full px-2.5 py-0.5">
            {stepLabel}
          </span>
          <div className="flex gap-1">
            {Array.from({ length: totalSteps }).map((_, i) => (
              <div
                key={i}
                className={`h-1.5 rounded-full transition-all ${
                  i === currentStep ? "w-4 bg-accent" : i < currentStep ? "w-1.5 bg-accent/40" : "w-1.5 bg-border/60"
                }`}
              />
            ))}
          </div>
        </div>

        {/* 标题 + 描述 */}
        <div className="space-y-1.5">
          <h4 className="text-sm font-bold text-foreground leading-tight">
            {scraperT[step.titleKey] || step.titleKey}
          </h4>
          <p className="text-xs text-muted leading-relaxed">
            {scraperT[step.descKey] || step.descKey}
          </p>
        </div>

        {/* 操作提示（可选） */}
        {step.actionKey && (
          <div className="flex items-start gap-2 rounded-lg bg-accent/5 border border-accent/20 p-2.5">
            <Lightbulb className="h-3.5 w-3.5 text-accent flex-shrink-0 mt-0.5" />
            <p className="text-[11px] text-accent/80 leading-relaxed">
              {scraperT[step.actionKey] || step.actionKey}
            </p>
          </div>
        )}

        {/* 导航按钮 */}
        <div className="flex items-center justify-between pt-1">
          <button
            onClick={skipGuide}
            className="text-[11px] text-muted hover:text-foreground transition-colors"
          >
            {scraperT.guideSkip || "跳过教程"}
          </button>
          <div className="flex items-center gap-2">
            {currentStep > 0 && (
              <button
                onClick={prevGuideStep}
                className="flex items-center gap-1 rounded-lg border border-border/40 px-3 py-1.5 text-[11px] font-medium text-muted hover:text-foreground hover:bg-card-hover transition-all"
              >
                <ChevronLeft className="h-3 w-3" />
                {scraperT.guidePrev || "上一步"}
              </button>
            )}
            <button
              onClick={currentStep < totalSteps - 1 ? nextGuideStep : finishGuide}
              className="flex items-center gap-1 rounded-lg bg-accent px-3 py-1.5 text-[11px] font-medium text-white shadow-sm hover:bg-accent-hover transition-all"
            >
              {currentStep < totalSteps - 1
                ? (scraperT.guideNext || "下一步")
                : (scraperT.guideFinish || "完成")
              }
              {currentStep < totalSteps - 1 && <ChevronRight className="h-3 w-3" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

