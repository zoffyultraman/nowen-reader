import { useState, useEffect } from "react";

// 模块级缓存，避免多个组件重复请求
let cachedStatus: { configured: boolean } | null = null;
let fetchPromise: Promise<void> | null = null;
let listeners: Array<() => void> = [];

function notifyListeners() {
  listeners.forEach((fn) => fn());
}

async function fetchAIStatus() {
  if (fetchPromise) return fetchPromise;
  fetchPromise = fetch("/api/ai/status")
    .then((r) => r.json())
    .then((data) => {
      cachedStatus = { configured: data.cloudAI?.configured ?? false };
      notifyListeners();
    })
    .catch(() => {
      cachedStatus = { configured: false };
      notifyListeners();
    })
    .finally(() => {
      fetchPromise = null;
    });
  return fetchPromise;
}

/**
 * 全局 AI 状态 hook
 * - aiConfigured: AI 是否已配置（enableCloudAI + API Key）
 * - refreshAIStatus: 手动刷新状态（如设置页保存后调用）
 */
export function useAIStatus() {
  const [configured, setConfigured] = useState(cachedStatus?.configured ?? false);

  useEffect(() => {
    // 注册监听
    const listener = () => {
      setConfigured(cachedStatus?.configured ?? false);
    };
    listeners.push(listener);

    // 首次加载时请求
    if (!cachedStatus) {
      fetchAIStatus();
    } else {
      setConfigured(cachedStatus.configured);
    }

    return () => {
      listeners = listeners.filter((fn) => fn !== listener);
    };
  }, []);

  const refreshAIStatus = () => {
    cachedStatus = null;
    fetchAIStatus();
  };

  return { aiConfigured: configured, refreshAIStatus };
}
