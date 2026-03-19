"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { User, Lock, Eye, EyeOff, Check, Loader2, KeyRound, Pencil } from "lucide-react";

export function AccountPanel() {
  const { user, refreshUser } = useAuth();

  return (
    <div className="space-y-6">
      {/* 用户信息概览 */}
      <div className="rounded-2xl border border-border/40 bg-gradient-to-br from-accent/5 via-card to-card p-5 sm:p-6">
        <div className="flex items-center gap-4">
          <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-accent/15 text-accent">
            <User className="h-7 w-7" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-foreground">
              {user?.nickname || user?.username}
            </h2>
            <p className="text-sm text-muted">
              @{user?.username} · {user?.role === "admin" ? "管理员" : "普通用户"}
            </p>
          </div>
        </div>
      </div>

      {/* 修改昵称 */}
      <NicknameSection onSuccess={refreshUser} />

      {/* 修改密码 */}
      <PasswordSection />
    </div>
  );
}

/* ── 修改昵称区域 ── */
function NicknameSection({ onSuccess }: { onSuccess: () => Promise<void> }) {
  const { user } = useAuth();
  const [nickname, setNickname] = useState(user?.nickname || "");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    if (!nickname.trim()) {
      setMessage({ type: "error", text: "昵称不能为空" });
      return;
    }

    if (nickname === user?.nickname) {
      setMessage({ type: "error", text: "昵称未发生变化" });
      return;
    }

    setSaving(true);
    try {
      const res = await fetch("/api/auth/users", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "updateProfile",
          nickname: nickname.trim(),
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "修改失败");
      setMessage({ type: "success", text: "昵称修改成功" });
      await onSuccess();
    } catch (err) {
      setMessage({ type: "error", text: err instanceof Error ? err.message : "修改失败" });
    } finally {
      setSaving(false);
    }
  };

  return (
    <section className="rounded-2xl border border-border/40 bg-card overflow-hidden">
      <div className="px-5 py-4 border-b border-border/30">
        <h3 className="text-sm font-semibold text-foreground flex items-center gap-2">
          <Pencil className="h-4 w-4 text-accent" />
          修改昵称
        </h3>
      </div>
      <form onSubmit={handleSubmit} className="p-5 space-y-4">
        <div>
          <label className="block text-xs font-medium text-muted mb-1.5">昵称</label>
          <div className="relative">
            <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type="text"
              value={nickname}
              onChange={(e) => {
                setNickname(e.target.value);
                setMessage(null);
              }}
              placeholder="输入新昵称"
              className="w-full pl-10 pr-4 py-2.5 bg-background border border-border rounded-lg text-sm text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent transition-colors"
              maxLength={32}
            />
          </div>
        </div>

        {message && (
          <div className={`text-xs px-3 py-2 rounded-lg ${
            message.type === "success"
              ? "bg-green-500/10 text-green-400"
              : "bg-red-500/10 text-red-400"
          }`}>
            {message.text}
          </div>
        )}

        <button
          type="submit"
          disabled={saving}
          className="flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-medium text-white hover:bg-accent/90 disabled:opacity-50 transition-colors"
        >
          {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="h-4 w-4" />}
          保存昵称
        </button>
      </form>
    </section>
  );
}

/* ── 修改密码区域 ── */
function PasswordSection() {
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showOld, setShowOld] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const resetForm = () => {
    setOldPassword("");
    setNewPassword("");
    setConfirmPassword("");
    setShowOld(false);
    setShowNew(false);
    setShowConfirm(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage(null);

    if (!oldPassword || !newPassword || !confirmPassword) {
      setMessage({ type: "error", text: "请填写所有密码字段" });
      return;
    }

    if (newPassword.length < 6) {
      setMessage({ type: "error", text: "新密码至少需要 6 个字符" });
      return;
    }

    if (newPassword !== confirmPassword) {
      setMessage({ type: "error", text: "两次输入的新密码不一致" });
      return;
    }

    if (oldPassword === newPassword) {
      setMessage({ type: "error", text: "新密码不能与旧密码相同" });
      return;
    }

    setSaving(true);
    try {
      const res = await fetch("/api/auth/users", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "changePassword",
          oldPassword,
          newPassword,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "修改密码失败");
      setMessage({ type: "success", text: "密码修改成功" });
      resetForm();
    } catch (err) {
      setMessage({ type: "error", text: err instanceof Error ? err.message : "修改密码失败" });
    } finally {
      setSaving(false);
    }
  };

  return (
    <section className="rounded-2xl border border-border/40 bg-card overflow-hidden">
      <div className="px-5 py-4 border-b border-border/30">
        <h3 className="text-sm font-semibold text-foreground flex items-center gap-2">
          <KeyRound className="h-4 w-4 text-accent" />
          修改密码
        </h3>
      </div>
      <form onSubmit={handleSubmit} className="p-5 space-y-4">
        {/* 当前密码 */}
        <div>
          <label className="block text-xs font-medium text-muted mb-1.5">当前密码</label>
          <div className="relative">
            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type={showOld ? "text" : "password"}
              value={oldPassword}
              onChange={(e) => {
                setOldPassword(e.target.value);
                setMessage(null);
              }}
              placeholder="输入当前密码"
              className="w-full pl-10 pr-10 py-2.5 bg-background border border-border rounded-lg text-sm text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent transition-colors"
            />
            <button
              type="button"
              onClick={() => setShowOld(!showOld)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted hover:text-foreground transition-colors"
            >
              {showOld ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
        </div>

        {/* 新密码 */}
        <div>
          <label className="block text-xs font-medium text-muted mb-1.5">新密码</label>
          <div className="relative">
            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type={showNew ? "text" : "password"}
              value={newPassword}
              onChange={(e) => {
                setNewPassword(e.target.value);
                setMessage(null);
              }}
              placeholder="输入新密码（至少 6 个字符）"
              className="w-full pl-10 pr-10 py-2.5 bg-background border border-border rounded-lg text-sm text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent transition-colors"
              minLength={6}
            />
            <button
              type="button"
              onClick={() => setShowNew(!showNew)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted hover:text-foreground transition-colors"
            >
              {showNew ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
        </div>

        {/* 确认新密码 */}
        <div>
          <label className="block text-xs font-medium text-muted mb-1.5">确认新密码</label>
          <div className="relative">
            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted" />
            <input
              type={showConfirm ? "text" : "password"}
              value={confirmPassword}
              onChange={(e) => {
                setConfirmPassword(e.target.value);
                setMessage(null);
              }}
              placeholder="再次输入新密码"
              className="w-full pl-10 pr-10 py-2.5 bg-background border border-border rounded-lg text-sm text-foreground placeholder:text-muted/50 focus:outline-none focus:border-accent transition-colors"
              minLength={6}
            />
            <button
              type="button"
              onClick={() => setShowConfirm(!showConfirm)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted hover:text-foreground transition-colors"
            >
              {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
        </div>

        {message && (
          <div className={`text-xs px-3 py-2 rounded-lg ${
            message.type === "success"
              ? "bg-green-500/10 text-green-400"
              : "bg-red-500/10 text-red-400"
          }`}>
            {message.text}
          </div>
        )}

        <button
          type="submit"
          disabled={saving}
          className="flex items-center gap-2 rounded-lg bg-accent px-4 py-2 text-sm font-medium text-white hover:bg-accent/90 disabled:opacity-50 transition-colors"
        >
          {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <KeyRound className="h-4 w-4" />}
          修改密码
        </button>
      </form>
    </section>
  );
}

export default AccountPanel;
