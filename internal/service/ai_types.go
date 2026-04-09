package service

// ============================================================
// Multimodal Image Content (0-3)
// ============================================================

// ImageContent 用于传入图片（支持 base64 或 URL）
type ImageContent struct {
	// Base64 编码的图片数据（不含 data:image/xxx;base64, 前缀）
	Base64 string `json:"base64,omitempty"`
	// 图片 URL
	URL string `json:"url,omitempty"`
	// MIME 类型，如 image/jpeg, image/png
	MimeType string `json:"mimeType,omitempty"`
}

// ============================================================
// Cloud LLM Unified Caller (增强版)
// ============================================================

// LLMCallOptions 调用选项
type LLMCallOptions struct {
	// 场景标识，用于统计（如 translate, summary, tag, chat）
	Scenario string
	// 覆盖 config 的 MaxTokens（0 表示使用 config 的值）
	MaxTokens int
	// 覆盖 config 的 Temperature（nil 表示使用默认 0.3）
	Temperature *float64
	// 图片列表（多模态）
	Images []ImageContent
}

// CallCloudLLM 调用云端 LLM，支持重试和 token 统计。
