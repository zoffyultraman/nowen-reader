package service

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// ============================================================
// AI Configuration
// ============================================================

type CloudProvider = string

type ProviderPreset struct {
	Name           string   `json:"name"`
	APIURL         string   `json:"apiUrl"`
	DefaultModel   string   `json:"defaultModel"`
	Models         []string `json:"models"`
	SupportsVision bool     `json:"supportsVision"`
	Region         string   `json:"region"`
}

var ProviderPresets = map[string]ProviderPreset{
	"openai":     {Name: "OpenAI", APIURL: "https://api.openai.com/v1", DefaultModel: "gpt-4o-mini", Models: []string{"gpt-4o", "gpt-4o-mini", "gpt-4.5-preview", "o1", "o1-mini", "o3-mini"}, SupportsVision: true, Region: "international"},
	"anthropic":  {Name: "Anthropic (Claude)", APIURL: "https://api.anthropic.com", DefaultModel: "claude-sonnet-4-20250514", Models: []string{"claude-sonnet-4-20250514", "claude-3-5-haiku-20241022"}, SupportsVision: true, Region: "international"},
	"google":     {Name: "Google Gemini", APIURL: "https://generativelanguage.googleapis.com/v1beta", DefaultModel: "gemini-2.0-flash", Models: []string{"gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-pro"}, SupportsVision: true, Region: "international"},
	"groq":       {Name: "Groq", APIURL: "https://api.groq.com/openai/v1", DefaultModel: "llama-3.3-70b-versatile", Models: []string{"llama-3.3-70b-versatile", "llama-3.1-8b-instant"}, SupportsVision: false, Region: "international"},
	"mistral":    {Name: "Mistral AI", APIURL: "https://api.mistral.ai/v1", DefaultModel: "mistral-small-latest", Models: []string{"mistral-large-latest", "mistral-small-latest"}, SupportsVision: true, Region: "international"},
	"cohere":     {Name: "Cohere", APIURL: "https://api.cohere.com/v2", DefaultModel: "command-r-plus", Models: []string{"command-r-plus", "command-r"}, SupportsVision: false, Region: "international"},
	"deepseek":   {Name: "DeepSeek (深度求索)", APIURL: "https://api.deepseek.com", DefaultModel: "deepseek-chat", Models: []string{"deepseek-chat", "deepseek-reasoner"}, SupportsVision: false, Region: "china"},
	"zhipu":      {Name: "Zhipu AI (智谱清言)", APIURL: "https://open.bigmodel.cn/api/paas/v4", DefaultModel: "glm-4v-flash", Models: []string{"glm-4v-flash", "glm-4-flash", "glm-4-plus"}, SupportsVision: true, Region: "china"},
	"qwen":       {Name: "Alibaba Qwen (通义千问)", APIURL: "https://dashscope.aliyuncs.com/compatible-mode/v1", DefaultModel: "qwen-vl-plus", Models: []string{"qwen-turbo", "qwen-plus", "qwen-max", "qwen-vl-plus"}, SupportsVision: true, Region: "china"},
	"doubao":     {Name: "Doubao (豆包/字节跳动)", APIURL: "https://ark.cn-beijing.volces.com/api/v3", DefaultModel: "doubao-1.5-pro-32k", Models: []string{"doubao-1.5-pro-32k", "doubao-1.5-lite-32k"}, SupportsVision: true, Region: "china"},
	"moonshot":   {Name: "Moonshot AI (月之暗面)", APIURL: "https://api.moonshot.cn/v1", DefaultModel: "moonshot-v1-8k", Models: []string{"moonshot-v1-8k", "moonshot-v1-32k"}, SupportsVision: false, Region: "china"},
	"baichuan":   {Name: "Baichuan (百川智能)", APIURL: "https://api.baichuan-ai.com/v1", DefaultModel: "Baichuan4", Models: []string{"Baichuan4", "Baichuan3-Turbo"}, SupportsVision: false, Region: "china"},
	"minimax":    {Name: "MiniMax", APIURL: "https://api.minimax.chat/v1", DefaultModel: "MiniMax-Text-01", Models: []string{"MiniMax-Text-01"}, SupportsVision: false, Region: "china"},
	"stepfun":    {Name: "StepFun (阶跃星辰)", APIURL: "https://api.stepfun.com/v1", DefaultModel: "step-1v-8k", Models: []string{"step-2-16k", "step-1v-8k"}, SupportsVision: true, Region: "china"},
	"yi":         {Name: "Yi (零一万物)", APIURL: "https://api.lingyiwanwu.com/v1", DefaultModel: "yi-vision", Models: []string{"yi-large", "yi-medium", "yi-vision"}, SupportsVision: true, Region: "china"},
	"compatible": {Name: "Custom (OpenAI Compatible)", APIURL: "", DefaultModel: "", Models: nil, SupportsVision: true, Region: "international"},
}

type AIConfig struct {
	EnableCloudAI bool   `json:"enableCloudAI"`
	CloudProvider string `json:"cloudProvider"`
	CloudAPIKey   string `json:"cloudApiKey"`
	CloudAPIURL   string `json:"cloudApiUrl"`
	CloudModel    string `json:"cloudModel"`
}

var defaultAIConfig = AIConfig{
	EnableCloudAI: false,
	CloudProvider: "openai",
	CloudAPIKey:   "",
	CloudAPIURL:   "https://api.openai.com/v1",
	CloudModel:    "gpt-4o-mini",
}

func aiConfigPath() string {
	return filepath.Join(config.DataDir(), "ai-config.json")
}

func LoadAIConfig() AIConfig {
	cfg := defaultAIConfig
	data, err := os.ReadFile(aiConfigPath())
	if err != nil {
		return cfg
	}
	_ = json.Unmarshal(data, &cfg)
	return cfg
}

func SaveAIConfig(cfg AIConfig) error {
	dir := filepath.Dir(aiConfigPath())
	os.MkdirAll(dir, 0755)
	data, _ := json.MarshalIndent(cfg, "", "  ")
	return os.WriteFile(aiConfigPath(), data, 0644)
}

// ============================================================
// AI Status
// ============================================================

type AIStatus struct {
	CloudAI struct {
		Configured bool   `json:"configured"`
		Provider   string `json:"provider"`
		Model      string `json:"model"`
	} `json:"cloudAI"`
}

func GetAIStatus() AIStatus {
	cfg := LoadAIConfig()

	var status AIStatus
	status.CloudAI.Configured = cfg.EnableCloudAI && cfg.CloudAPIKey != ""
	status.CloudAI.Provider = cfg.CloudProvider
	status.CloudAI.Model = cfg.CloudModel
	return status
}

// ============================================================
// Cloud LLM Unified Caller
// ============================================================

// CallCloudLLM calls a cloud LLM provider with unified interface.
func CallCloudLLM(cfg AIConfig, systemPrompt, userPrompt string) (string, error) {
	if !cfg.EnableCloudAI || cfg.CloudAPIKey == "" {
		return "", fmt.Errorf("cloud AI not configured")
	}

	provider := cfg.CloudProvider
	apiURL := cfg.CloudAPIURL
	if apiURL == "" {
		if p, ok := ProviderPresets[provider]; ok {
			apiURL = p.APIURL
		}
	}

	switch provider {
	case "anthropic":
		return callAnthropic(cfg, apiURL, systemPrompt, userPrompt)
	case "google":
		return callGemini(cfg, apiURL, systemPrompt, userPrompt)
	default:
		return callOpenAICompatible(cfg, apiURL, systemPrompt, userPrompt)
	}
}

func callOpenAICompatible(cfg AIConfig, apiURL, systemPrompt, userPrompt string) (string, error) {
	reqURL := apiURL + "/chat/completions"
	body, _ := json.Marshal(map[string]interface{}{
		"model": cfg.CloudModel,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": userPrompt},
		},
		"max_tokens":  500,
		"temperature": 0.3,
	})

	client := &http.Client{Timeout: 60 * time.Second}
	req, _ := http.NewRequest("POST", reqURL, strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+cfg.CloudAPIKey)

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OpenAI API error %d: %s", resp.StatusCode, string(respBody)[:200])
	}

	var data struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return "", err
	}
	if len(data.Choices) == 0 {
		return "", fmt.Errorf("no response from LLM")
	}
	return data.Choices[0].Message.Content, nil
}

func callAnthropic(cfg AIConfig, apiURL, systemPrompt, userPrompt string) (string, error) {
	reqURL := apiURL + "/v1/messages"
	body, _ := json.Marshal(map[string]interface{}{
		"model":      cfg.CloudModel,
		"max_tokens": 500,
		"system":     systemPrompt,
		"messages":   []map[string]interface{}{{"role": "user", "content": userPrompt}},
	})

	client := &http.Client{Timeout: 60 * time.Second}
	req, _ := http.NewRequest("POST", reqURL, strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", cfg.CloudAPIKey)
	req.Header.Set("anthropic-version", "2023-06-01")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("Anthropic API error %d: %s", resp.StatusCode, string(respBody)[:200])
	}

	var data struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return "", err
	}
	for _, c := range data.Content {
		if c.Type == "text" {
			return c.Text, nil
		}
	}
	return "", fmt.Errorf("no text in Anthropic response")
}

func callGemini(cfg AIConfig, apiURL, systemPrompt, userPrompt string) (string, error) {
	model := cfg.CloudModel
	if model == "" {
		model = "gemini-2.0-flash"
	}
	reqURL := fmt.Sprintf("%s/models/%s:generateContent?key=%s", apiURL, model, cfg.CloudAPIKey)

	body, _ := json.Marshal(map[string]interface{}{
		"contents": []map[string]interface{}{
			{"parts": []map[string]string{{"text": systemPrompt + "\n\n" + userPrompt}}},
		},
		"generationConfig": map[string]interface{}{
			"temperature":     0.3,
			"maxOutputTokens": 500,
		},
	})

	client := &http.Client{Timeout: 60 * time.Second}
	req, _ := http.NewRequest("POST", reqURL, strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("Gemini API error %d: %s", resp.StatusCode, string(respBody)[:200])
	}

	var data struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return "", err
	}
	if len(data.Candidates) > 0 && len(data.Candidates[0].Content.Parts) > 0 {
		return data.Candidates[0].Content.Parts[0].Text, nil
	}
	return "", fmt.Errorf("no response from Gemini")
}

// ============================================================
// Translate metadata fields via Cloud LLM
// ============================================================

// TranslateMetadataFields translates metadata fields to the target language.
func TranslateMetadataFields(cfg AIConfig, fields map[string]string, targetLang string) (map[string]string, error) {
	if !cfg.EnableCloudAI || cfg.CloudAPIKey == "" {
		return nil, fmt.Errorf("cloud AI not configured")
	}

	if len(fields) == 0 {
		return nil, nil
	}

	langName := "English"
	if strings.HasPrefix(targetLang, "zh") {
		langName = "Chinese (简体中文)"
	}

	systemPrompt := fmt.Sprintf(`You are a professional translator specializing in manga/comic metadata. Translate the given fields to %s. Keep proper nouns in their commonly known form. For genre/tag terms, use standard localized terms.
Respond ONLY with a valid JSON object containing the translated fields.`, langName)

	fieldsJSON, _ := json.MarshalIndent(fields, "", "  ")
	userPrompt := fmt.Sprintf("Translate these metadata fields to %s:\n\n%s\n\nReturn a JSON object with the same keys and translated values.", langName, string(fieldsJSON))

	content, err := CallCloudLLM(cfg, systemPrompt, userPrompt)
	if err != nil {
		return nil, err
	}

	// Clean markdown code blocks
	content = strings.ReplaceAll(content, "```json", "")
	content = strings.ReplaceAll(content, "```", "")
	content = strings.TrimSpace(content)

	var result map[string]string
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		// Try to extract JSON object
		start := strings.Index(content, "{")
		end := strings.LastIndex(content, "}")
		if start >= 0 && end > start {
			content = content[start : end+1]
			if err := json.Unmarshal([]byte(content), &result); err != nil {
				return nil, fmt.Errorf("failed to parse AI response: %w", err)
			}
		} else {
			return nil, fmt.Errorf("failed to parse AI response: %w", err)
		}
	}
	return result, nil
}
