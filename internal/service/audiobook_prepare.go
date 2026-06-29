package service

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log"
	"strings"
)

// ============================================================
// 听书 AI 文本增强
// ============================================================

// AudiobookSegment 朗读片段
type AudiobookSegment struct {
	Type         string `json:"type"`         // narration | dialogue | thought | system
	Speaker      string `json:"speaker"`      // 说话人（可为空）
	Text         string `json:"text"`         // 适合朗读的文本
	PauseAfterMs int    `json:"pauseAfterMs"` // 朗读后暂停时间（毫秒）
}

// AudiobookPrepareResult 听书准备结果
type AudiobookPrepareResult struct {
	ChapterIndex int               `json:"chapterIndex"`
	Title        string            `json:"title"`
	Recap        string            `json:"recap"`        // 前情提要
	Segments     []AudiobookSegment `json:"segments"`
	Source       string            `json:"source"`       // ai | fallback
	Model        string            `json:"model"`
	Cached       bool              `json:"cached"`
}

// audiobookCache 听书缓存（内存缓存，重启后失效）
var audiobookCache = make(map[string]AudiobookPrepareResult)

// AudiobookCacheKey 生成缓存 key
func AudiobookCacheKey(comicID string, chapterIndex int, model string, contentHash string) string {
	return fmt.Sprintf("%s:%d:%s:%s", comicID, chapterIndex, model, contentHash)
}

// ContentHash 计算内容哈希
func ContentHash(content string) string {
	h := sha256.Sum256([]byte(content))
	return fmt.Sprintf("%x", h[:8])
}

// PrepareAudiobook 准备听书文本
func PrepareAudiobook(comicID string, chapterIndex int, chapterTitle string, content string, includeRecap bool, forceRefresh bool) (*AudiobookPrepareResult, error) {
	cfg := LoadAIConfig()

	// 检查 AI 是否可用
	if !cfg.EnableCloudAI && !cfg.EnableLocalAI {
		return nil, fmt.Errorf("AI 未配置")
	}
	if cfg.EnableCloudAI && cfg.CloudAPIKey == "" && !(cfg.EnableLocalAI && LocalAI.IsRunning()) {
		return nil, fmt.Errorf("AI 未配置")
	}

	// 确定使用的模型
	model := cfg.CloudModel
	if cfg.EnableLocalAI && LocalAI.IsRunning() {
		model = "local:" + cfg.LocalModelPath
	}

	// 检查缓存
	contentHash := ContentHash(content)
	cacheKey := AudiobookCacheKey(comicID, chapterIndex, model, contentHash)

	if !forceRefresh {
		if cached, ok := audiobookCache[cacheKey]; ok {
			cached.Cached = true
			return &cached, nil
		}
	}

	// 构建 prompt
	prompt := buildAudiobookPrompt(chapterTitle, content, includeRecap)

	// 调用 AI
	maxTokens := 4000
	if len(content) > 10000 {
		maxTokens = 8000
	}

	result, err := CallCloudLLM(cfg, prompt.System, prompt.User, &LLMCallOptions{
		Scenario:  "audiobook",
		MaxTokens: maxTokens,
	})
	if err != nil {
		log.Printf("[audiobook] AI 调用失败: %v", err)
		return nil, err
	}

	// 解析 AI 返回的 JSON
	parsed, err := parseAudiobookResult(result, chapterIndex, chapterTitle)
	if err != nil {
		log.Printf("[audiobook] 解析 AI 结果失败: %v", err)
		return nil, err
	}

	// 设置元信息
	parsed.Model = model
	parsed.Source = "ai"
	parsed.Cached = false

	// 缓存结果
	audiobookCache[cacheKey] = *parsed

	return parsed, nil
}

// audiobookPrompt 听书 prompt
type audiobookPrompt struct {
	System string
	User   string
}

// buildAudiobookPrompt 构建听书 prompt
func buildAudiobookPrompt(chapterTitle string, content string, includeRecap bool) audiobookPrompt {
	system := `你是一个专业的文本处理助手。你的任务是将小说章节文本处理成适合 TTS 朗读的格式。

要求：
1. 不改写剧情，不删减有效正文
2. 移除广告、水印、站点说明、乱码、重复空行、无意义页眉页脚
3. 把超长段落拆成适合 TTS 的短句（每个片段 20-120 个中文字符）
4. 保留对话语气和自然停顿
5. 识别旁白（narration）、角色台词（dialogue）、心理活动（thought）
6. 输出必须是严格 JSON 格式

输出 JSON 格式：
{
  "recap": "前情提要，50字以内，如果没有上文则为空字符串",
  "segments": [
    {
      "type": "narration",
      "speaker": "",
      "text": "适合朗读的一小段文本",
      "pauseAfterMs": 500
    },
    {
      "type": "dialogue",
      "speaker": "角色名",
      "text": "角色说的话",
      "pauseAfterMs": 700
    }
  ]
}

注意：
- type 只能是 narration / dialogue / thought / system 之一
- narration 是旁白，speaker 为空
- dialogue 是对话，speaker 为角色名
- thought 是心理活动，speaker 为空
- system 是系统文本（如章节标题、作者注释等）
- pauseAfterMs 建议 300-1000，对话结尾可稍长
- 只输出 JSON，不要有其他内容`

	user := fmt.Sprintf("请处理以下章节文本，章节标题：%s\n\n%s", chapterTitle, content)

	if !includeRecap {
		user = "不需要前情提要（recap 设为空字符串）。\n\n" + user
	}

	return audiobookPrompt{
		System: system,
		User:   user,
	}
}

// parseAudiobookResult 解析 AI 返回的结果
func parseAudiobookResult(result string, chapterIndex int, chapterTitle string) (*AudiobookPrepareResult, error) {
	// 尝试提取 JSON（AI 可能会在 JSON 前后添加说明文字）
	jsonStr := extractJSON(result)
	if jsonStr == "" {
		return nil, fmt.Errorf("无法从 AI 结果中提取 JSON")
	}

	var parsed struct {
		Recap    string `json:"recap"`
		Segments []struct {
			Type         string `json:"type"`
			Speaker      string `json:"speaker"`
			Text         string `json:"text"`
			PauseAfterMs int    `json:"pauseAfterMs"`
		} `json:"segments"`
	}

	if err := json.Unmarshal([]byte(jsonStr), &parsed); err != nil {
		return nil, fmt.Errorf("JSON 解析失败: %v", err)
	}

	if len(parsed.Segments) == 0 {
		return nil, fmt.Errorf("AI 返回的 segments 为空")
	}

	// 构建结果
	result2 := &AudiobookPrepareResult{
		ChapterIndex: chapterIndex,
		Title:        chapterTitle,
		Recap:        parsed.Recap,
		Segments:     make([]AudiobookSegment, 0, len(parsed.Segments)),
	}

	for _, seg := range parsed.Segments {
		// 验证 type
		validTypes := map[string]bool{
			"narration": true,
			"dialogue":  true,
			"thought":   true,
			"system":    true,
		}
		if !validTypes[seg.Type] {
			seg.Type = "narration"
		}

		// 验证文本不为空
		text := strings.TrimSpace(seg.Text)
		if text == "" {
			continue
		}

		// 验证 pauseAfterMs
		if seg.PauseAfterMs <= 0 {
			seg.PauseAfterMs = 500
		}
		if seg.PauseAfterMs > 2000 {
			seg.PauseAfterMs = 2000
		}

		result2.Segments = append(result2.Segments, AudiobookSegment{
			Type:         seg.Type,
			Speaker:      strings.TrimSpace(seg.Speaker),
			Text:         text,
			PauseAfterMs: seg.PauseAfterMs,
		})
	}

	return result2, nil
}

// extractJSON 从文本中提取 JSON
func extractJSON(text string) string {
	// 查找第一个 { 的位置
	start := strings.Index(text, "{")
	if start == -1 {
		return ""
	}

	// 从后往前查找最后一个 }
	end := strings.LastIndex(text, "}")
	if end == -1 || end <= start {
		return ""
	}

	return text[start : end+1]
}

// ClearAudiobookCache 清除听书缓存
func ClearAudiobookCache() {
	audiobookCache = make(map[string]AudiobookPrepareResult)
}
