package handler

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nowen-reader/nowen-reader/internal/config"
	"github.com/nowen-reader/nowen-reader/internal/service"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

type MetadataHandler struct{}

func NewMetadataHandler() *MetadataHandler { return &MetadataHandler{} }

// POST /api/metadata/search
// Also handles GET /api/metadata/search?q=...&sources=...&lang=...
func (h *MetadataHandler) Search(c *gin.Context) {
	var query, lang string
	var sources []string

	var contentType string

	if c.Request.Method == "GET" {
		query = c.Query("q")
		lang = c.DefaultQuery("lang", "en")
		contentType = c.Query("contentType")
		if s := c.Query("sources"); s != "" {
			sources = strings.Split(s, ",")
		}
	} else {
		var body struct {
			Query       string   `json:"query"`
			Sources     []string `json:"sources"`
			Lang        string   `json:"lang"`
			ContentType string   `json:"contentType"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(400, gin.H{"error": "invalid request body"})
			return
		}
		query = body.Query
		sources = body.Sources
		lang = body.Lang
		contentType = body.ContentType
		if lang == "" {
			lang = "en"
		}
	}

	if query == "" {
		c.JSON(400, gin.H{"error": "query is required"})
		return
	}

	results := service.SearchMetadata(query, sources, lang, contentType)
	if results == nil {
		results = []service.ComicMetadata{}
	}
	c.JSON(200, gin.H{"results": results})
}

// POST /api/metadata/apply
func (h *MetadataHandler) Apply(c *gin.Context) {
	var body struct {
		ComicID   string                `json:"comicId"`
		Metadata  service.ComicMetadata `json:"metadata"`
		Lang      string                `json:"lang"`
		Overwrite bool                  `json:"overwrite"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "invalid request body"})
		return
	}
	if body.ComicID == "" {
		c.JSON(400, gin.H{"error": "comicId and metadata are required"})
		return
	}

	comic, err := service.ApplyMetadata(body.ComicID, body.Metadata, body.Lang, body.Overwrite)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to apply metadata"})
		return
	}
	c.JSON(200, gin.H{"comic": comic})
}

// POST /api/metadata/scan
func (h *MetadataHandler) Scan(c *gin.Context) {
	var body struct {
		ComicID string `json:"comicId"`
		Lang    string `json:"lang"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.ComicID == "" {
		c.JSON(400, gin.H{"error": "comicId is required"})
		return
	}
	if body.Lang == "" {
		body.Lang = "en"
	}

	comic, err := store.GetComicByID(body.ComicID)
	if err != nil || comic == nil {
		c.JSON(404, gin.H{"error": "Comic not found"})
		return
	}

	// Find actual file path
	filePath := findComicFile(comic.Filename)
	if filePath == "" {
		c.JSON(404, gin.H{"error": "Comic file not found on disk"})
		return
	}

	// Try extracting ComicInfo.xml first
	comicInfo, _ := service.ExtractComicInfoFromArchive(filePath)
	if comicInfo != nil && comicInfo.Title != "" {
		result, err := service.ApplyMetadata(body.ComicID, *comicInfo, body.Lang, false)
		if err != nil {
			c.JSON(500, gin.H{"error": "Failed to apply metadata"})
			return
		}
		c.JSON(200, gin.H{
			"comic":  result,
			"source": "comicinfo",
		})
		return
	}

	// Fallback: search online by filename
	searchQuery := service.ExtractSearchQuery(comic.Filename)
	if searchQuery == "" {
		c.JSON(200, gin.H{
			"comic":   comic,
			"source":  "none",
			"message": "No search query could be derived from filename",
		})
		return
	}

	// 根据文件名自动判断内容类型
	scanContentType := "comic"
	if service.IsNovelFilename(comic.Filename) {
		scanContentType = "novel"
	}

	results := service.SearchMetadata(searchQuery, nil, body.Lang, scanContentType)
	if len(results) == 0 {
		c.JSON(200, gin.H{
			"comic":   comic,
			"source":  "none",
			"message": "No metadata found online",
		})
		return
	}

	// Apply best match — scan 是用户主动触发的，使用 overwrite 覆盖旧数据
	updated, err := service.ApplyMetadata(body.ComicID, results[0], body.Lang, true)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to apply metadata"})
		return
	}
	c.JSON(200, gin.H{
		"comic":  updated,
		"source": results[0].Source,
	})
}

// POST /api/metadata/novel-scan — 小说专用刮削接口
// 优先从 EPUB OPF 提取本地元数据，再通过小说数据源在线搜索。
func (h *MetadataHandler) NovelScan(c *gin.Context) {
	var body struct {
		ComicID string `json:"comicId"`
		Lang    string `json:"lang"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.ComicID == "" {
		c.JSON(400, gin.H{"error": "comicId is required"})
		return
	}
	if body.Lang == "" {
		body.Lang = "en"
	}

	comic, err := store.GetComicByID(body.ComicID)
	if err != nil || comic == nil {
		c.JSON(404, gin.H{"error": "Comic not found"})
		return
	}

	// 查找文件路径
	filePath := findComicFile(comic.Filename)
	if filePath == "" {
		c.JSON(404, gin.H{"error": "File not found on disk"})
		return
	}

	// 步骤1：尝试从 EPUB OPF 提取本地元数据
	ext := strings.ToLower(filepath.Ext(comic.Filename))
	if ext == ".epub" {
		epubMeta, err := service.ExtractEpubMetadata(filePath)
		if err == nil && epubMeta != nil && epubMeta.Title != "" {
			result, err := service.ApplyMetadata(body.ComicID, *epubMeta, body.Lang, false)
			if err != nil {
				c.JSON(500, gin.H{"error": "Failed to apply metadata"})
				return
			}
			c.JSON(200, gin.H{
				"comic":  result,
				"source": "epub_opf",
			})
			return
		}
	}

	// 步骤2：对于 MOBI/AZW3，尝试先转换为 EPUB 再提取
	if ext == ".mobi" || ext == ".azw3" {
		// MOBI/AZW3 会通过 Calibre 转换为 EPUB，转换后的路径在 cache 中
		// 直接走在线搜索即可（MOBI 内嵌元数据较少且不标准）
	}

	// 步骤3：在线搜索兜底
	searchQuery := service.ExtractSearchQuery(comic.Filename)
	if searchQuery == "" {
		c.JSON(200, gin.H{
			"comic":   comic,
			"source":  "none",
			"message": "No search query could be derived from filename",
		})
		return
	}

	results := service.SearchMetadata(searchQuery, nil, body.Lang, "novel")
	if len(results) == 0 {
		c.JSON(200, gin.H{
			"comic":   comic,
			"source":  "none",
			"message": "No metadata found online",
		})
		return
	}

	// 应用最佳匹配结果 — novel-scan 是用户主动触发的，使用 overwrite 覆盖旧数据
	updated, err := service.ApplyMetadata(body.ComicID, results[0], body.Lang, true)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to apply metadata"})
		return
	}
	c.JSON(200, gin.H{
		"comic":  updated,
		"source": results[0].Source,
	})
}

// POST /api/metadata/batch — SSE stream
func (h *MetadataHandler) Batch(c *gin.Context) {
	var body struct {
		Mode        string `json:"mode"` // "all" or "missing"
		Lang        string `json:"lang"`
		UpdateTitle bool   `json:"updateTitle"` // 是否同时更新书名/漫画名
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		body.Mode = "all"
		body.Lang = "en"
	}
	if body.Lang == "" {
		body.Lang = "en"
	}

	// Get all comics
	allComics, err := store.GetAllComicIDsAndFilenames()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get comics"})
		return
	}

	// If mode=missing, filter to only those without metadata
	var comics []store.ComicIDFilename
	if body.Mode == "missing" {
		for _, comic := range allComics {
			detail, _ := store.GetComicByID(comic.ID)
			if detail != nil && detail.MetadataSource == "" {
				comics = append(comics, comic)
			}
		}
	} else {
		comics = allComics
	}

	total := len(comics)

	// SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")
	c.Writer.Flush()

	sendSSE := func(data interface{}) {
		jsonData, _ := json.Marshal(data)
		fmt.Fprintf(c.Writer, "data: %s\n\n", string(jsonData))
		c.Writer.Flush()
	}

	sendSSE(gin.H{"type": "start", "total": total})

	success := 0
	failed := 0

	for i, comic := range comics {
		progress := gin.H{
			"type":     "progress",
			"current":  i + 1,
			"total":    total,
			"comicId":  comic.ID,
			"filename": comic.Filename,
		}

		filePath := findComicFile(comic.Filename)

		isNovel := service.IsNovelFilename(comic.Filename)

		// 小说文件：优先尝试从 EPUB OPF 提取本地元数据
		if isNovel && filePath != "" {
			ext := strings.ToLower(filepath.Ext(comic.Filename))
			if ext == ".epub" {
				epubMeta, err := service.ExtractEpubMetadata(filePath)
				if err == nil && epubMeta != nil && epubMeta.Title != "" {
					_, err := service.ApplyMetadata(comic.ID, *epubMeta, body.Lang, body.UpdateTitle)
					if err == nil {
						progress["status"] = "success"
						progress["source"] = "epub_opf"
						if body.UpdateTitle && epubMeta.Title != "" {
							progress["matchTitle"] = epubMeta.Title
						}
						sendSSE(progress)
						success++
						continue
					}
				}
			}
		}

		// 漫画文件：尝试从 ComicInfo.xml 提取
		if !isNovel && filePath != "" {
			comicInfo, _ := service.ExtractComicInfoFromArchive(filePath)
			if comicInfo != nil && comicInfo.Title != "" {
				_, err := service.ApplyMetadata(comic.ID, *comicInfo, body.Lang, body.UpdateTitle)
				if err == nil {
					progress["status"] = "success"
					progress["source"] = "comicinfo"
					if body.UpdateTitle && comicInfo.Title != "" {
						progress["matchTitle"] = comicInfo.Title
					}
					sendSSE(progress)
					success++
					continue
				}
			}
		}

		// Online search fallback
		searchQuery := service.ExtractSearchQuery(comic.Filename)
		if searchQuery == "" {
			progress["status"] = "skipped"
			progress["message"] = "No search query"
			sendSSE(progress)
			failed++
			continue
		}

		// 批量在线搜索限流：每次请求之间间隔 1.5 秒，避免触发外部 API 的 429
		time.Sleep(1500 * time.Millisecond)

		// 根据文件名自动判断内容类型
		batchContentType := "comic"
		if service.IsNovelFilename(comic.Filename) {
			batchContentType = "novel"
		}

		results := service.SearchMetadata(searchQuery, nil, body.Lang, batchContentType)
		if len(results) > 0 {
			_, err := service.ApplyMetadata(comic.ID, results[0], body.Lang, body.UpdateTitle)
			if err == nil {
				progress["status"] = "success"
				progress["source"] = results[0].Source
				if body.UpdateTitle && results[0].Title != "" {
					progress["matchTitle"] = results[0].Title
				}
				sendSSE(progress)
				success++
				continue
			}
		}

		progress["status"] = "failed"
		progress["message"] = "No metadata found"
		sendSSE(progress)
		failed++
	}

	sendSSE(gin.H{
		"type":    "complete",
		"total":   total,
		"success": success,
		"failed":  failed,
	})
}

// POST /api/metadata/translate-batch — SSE stream
func (h *MetadataHandler) TranslateBatch(c *gin.Context) {
	var body struct {
		TargetLang string `json:"targetLang"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.TargetLang == "" {
		c.JSON(400, gin.H{"error": "targetLang is required"})
		return
	}

	allComics, err := store.GetAllComicIDsAndFilenames()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get comics"})
		return
	}

	total := len(allComics)

	// SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")
	c.Writer.Flush()

	sendSSE := func(data interface{}) {
		jsonData, _ := json.Marshal(data)
		fmt.Fprintf(c.Writer, "data: %s\n\n", string(jsonData))
		c.Writer.Flush()
	}

	sendSSE(gin.H{"type": "start", "total": total})

	aiCfg := service.LoadAIConfig()
	translated := 0
	skipped := 0

	for i, comic := range allComics {
		detail, err := store.GetComicByID(comic.ID)
		if err != nil || detail == nil {
			sendSSE(gin.H{"type": "progress", "current": i + 1, "total": total, "status": "skipped"})
			skipped++
			continue
		}

		updates := map[string]interface{}{}

		// Translate genre locally
		if detail.Genre != "" {
			translatedGenre := service.TranslateGenre(detail.Genre, body.TargetLang)
			if translatedGenre != detail.Genre {
				updates["genre"] = translatedGenre
			}
		}

		// Try AI translation for other fields
		if aiCfg.EnableCloudAI && aiCfg.CloudAPIKey != "" {
			fields := map[string]string{}
			if detail.Title != "" {
				fields["title"] = detail.Title
			}
			if detail.Description != "" {
				fields["description"] = detail.Description
			}

			if len(fields) > 0 {
				result, err := service.TranslateMetadataFields(aiCfg, fields, body.TargetLang)
				if err == nil && result != nil {
					for k, v := range result {
						if v != "" {
							updates[k] = v
						}
					}
				}
			}
		}

		if len(updates) > 0 {
			_ = store.UpdateComicFields(comic.ID, updates)
			translated++
			sendSSE(gin.H{"type": "progress", "current": i + 1, "total": total, "status": "translated", "comicId": comic.ID})
		} else {
			skipped++
			sendSSE(gin.H{"type": "progress", "current": i + 1, "total": total, "status": "skipped"})
		}
	}

	sendSSE(gin.H{
		"type":       "complete",
		"total":      total,
		"translated": translated,
		"skipped":    skipped,
	})
}

// GET /api/metadata/stats — 元数据统计概览
func (h *MetadataHandler) Stats(c *gin.Context) {
	allComics, err := store.GetAllComicIDsAndFilenames()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get comics"})
		return
	}

	total := len(allComics)
	withMeta := 0
	missing := 0

	for _, comic := range allComics {
		detail, _ := store.GetComicByID(comic.ID)
		if detail != nil && detail.MetadataSource != "" {
			withMeta++
		} else {
			missing++
		}
	}

	c.JSON(200, gin.H{
		"total":        total,
		"withMetadata": withMeta,
		"missing":      missing,
	})
}

// POST /api/metadata/ai-batch — AI 智能批量刮削 (SSE)
// 流水线：AI 解析文件名 → 在线搜索 → AI 补全 → 应用元数据
func (h *MetadataHandler) AIBatch(c *gin.Context) {
	var body struct {
		Mode        string `json:"mode"` // "all" or "missing"
		Lang        string `json:"lang"`
		UpdateTitle bool   `json:"updateTitle"` // 是否同时更新书名/漫画名
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		body.Mode = "missing"
		body.Lang = "zh"
	}
	if body.Lang == "" {
		body.Lang = "zh"
	}

	// 检查 AI 配置
	aiCfg := service.LoadAIConfig()
	if !aiCfg.EnableCloudAI || aiCfg.CloudAPIKey == "" {
		c.JSON(400, gin.H{"error": "AI not configured"})
		return
	}

	allComics, err := store.GetAllComicIDsAndFilenames()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get comics"})
		return
	}

	// 根据 mode 过滤
	var comics []store.ComicIDFilename
	if body.Mode == "missing" {
		for _, comic := range allComics {
			detail, _ := store.GetComicByID(comic.ID)
			if detail != nil && detail.MetadataSource == "" {
				comics = append(comics, comic)
			}
		}
	} else {
		comics = allComics
	}

	total := len(comics)

	// SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")
	c.Writer.Flush()

	sendSSE := func(data interface{}) {
		jsonData, _ := json.Marshal(data)
		fmt.Fprintf(c.Writer, "data: %s\n\n", string(jsonData))
		c.Writer.Flush()
	}

	sendSSE(gin.H{"type": "start", "total": total})

	success := 0
	failed := 0

	for i, comic := range comics {
		progress := gin.H{
			"type":     "progress",
			"current":  i + 1,
			"total":    total,
			"comicId":  comic.ID,
			"filename": comic.Filename,
		}

		// Step 1: AI 解析文件名
		progress["step"] = "parse"
		sendSSE(progress)

		parsed, err := service.AIParseFilename(aiCfg, comic.Filename)
		var searchQuery string
		if err == nil && parsed != nil && parsed.Title != "" {
			searchQuery = parsed.Title
			if parsed.Author != "" {
				searchQuery = parsed.Title + " " + parsed.Author
			}
			progress["parsed"] = parsed
		} else {
			// AI 解析失败，降级为正则清洗
			searchQuery = service.ExtractSearchQuery(comic.Filename)
		}

		if searchQuery == "" {
			progress["status"] = "failed"
			progress["step"] = "done"
			progress["message"] = "No search query"
			sendSSE(progress)
			failed++
			continue
		}

		// Step 2: 在线搜索元数据
		progress["step"] = "search"
		sendSSE(progress)

		// 限流防429
		time.Sleep(1500 * time.Millisecond)

		contentType := "comic"
		if service.IsNovelFilename(comic.Filename) {
			contentType = "novel"
		}

		results := service.SearchMetadata(searchQuery, nil, body.Lang, contentType)

		if len(results) > 0 {
			// Step 3: 找到结果，应用最佳匹配
			progress["step"] = "apply"
			progress["resultsCount"] = len(results)
			sendSSE(progress)

			_, err := service.ApplyMetadata(comic.ID, results[0], body.Lang, body.UpdateTitle)
			if err == nil {
				progress["status"] = "success"
				progress["step"] = "done"
				progress["source"] = results[0].Source
				progress["matchTitle"] = results[0].Title
				sendSSE(progress)
				success++
				continue
			}
		}

		// Step 4: 在线搜索无结果，尝试 AI 补全元数据
		progress["step"] = "ai-complete"
		sendSSE(progress)

		detail, _ := store.GetComicByID(comic.ID)
		var coverData []byte
		coverBytes, err := service.GetComicThumbnail(comic.ID)
		if err == nil && len(coverBytes) > 0 {
			coverData = coverBytes
		}

		title := comic.Filename
		if detail != nil && detail.Title != "" {
			title = detail.Title
		}

		meta, err := service.AICompleteMetadata(aiCfg, comic.Filename, title, coverData, body.Lang)
		if err == nil && meta != nil {
			updates := map[string]interface{}{}
			if meta.Title != "" && body.UpdateTitle {
				updates["title"] = meta.Title
			}
			if meta.Author != "" {
				updates["author"] = meta.Author
			}
			if meta.Genre != "" {
				updates["genre"] = meta.Genre
			}
			if meta.Description != "" {
				updates["description"] = meta.Description
			}
			if meta.Language != "" {
				updates["language"] = meta.Language
			}
			if meta.Year != nil {
				updates["year"] = *meta.Year
			}
			if len(updates) > 0 {
				updates["metadataSource"] = "ai_complete"
				_ = store.UpdateComicFields(comic.ID, updates)
			}
			// 添加标签
			if meta.Tags != "" {
				var tags []string
				for _, t := range strings.Split(meta.Tags, ",") {
					t = strings.TrimSpace(t)
					if t != "" {
						tags = append(tags, t)
					}
				}
				if len(tags) > 0 {
					_ = store.AddTagsToComic(comic.ID, tags)
				}
			}

			progress["status"] = "success"
			progress["step"] = "done"
			progress["source"] = "ai_complete"
			sendSSE(progress)
			success++
			continue
		}

		progress["status"] = "failed"
		progress["step"] = "done"
		progress["message"] = "No metadata found"
		sendSSE(progress)
		failed++
	}

	sendSSE(gin.H{
		"type":    "complete",
		"total":   total,
		"success": success,
		"failed":  failed,
	})
}

// GET /api/metadata/library — 书库管理列表（带元数据状态过滤）
func (h *MetadataHandler) Library(c *gin.Context) {
	search := c.Query("search")
	metaFilter := c.DefaultQuery("metaFilter", "all") // "all" | "with" | "missing"
	contentType := c.Query("contentType")             // "comic" | "novel" | ""
	page := 1
	pageSize := 20
	if p := c.Query("page"); p != "" {
		if n, err := fmt.Sscanf(p, "%d", &page); n == 0 || err != nil {
			page = 1
		}
	}
	if ps := c.Query("pageSize"); ps != "" {
		if n, err := fmt.Sscanf(ps, "%d", &pageSize); n == 0 || err != nil {
			pageSize = 20
		}
	}
	if pageSize > 100 {
		pageSize = 100
	}

	result, err := store.GetAllComics(store.ComicListOptions{
		Search:      search,
		SortBy:      "title",
		SortOrder:   "asc",
		Page:        page,
		PageSize:    pageSize,
		ContentType: contentType,
		MetaFilter:  metaFilter, // SQL 层面过滤，分页准确
	})
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get comics"})
		return
	}

	type LibraryItemTag struct {
		Name  string `json:"name"`
		Color string `json:"color"`
	}
	type LibraryItem struct {
		ID             string           `json:"id"`
		Title          string           `json:"title"`
		Filename       string           `json:"filename"`
		Author         string           `json:"author"`
		Genre          string           `json:"genre"`
		Description    string           `json:"description"`
		Year           *int             `json:"year"`
		MetadataSource string           `json:"metadataSource"`
		HasMetadata    bool             `json:"hasMetadata"`
		ContentType    string           `json:"contentType"`
		Tags           []LibraryItemTag `json:"tags"`
	}

	var items []LibraryItem
	for _, comic := range result.Comics {
		hasMeta := comic.MetadataSource != ""

		ct := comic.ComicType
		if ct == "" {
			if service.IsNovelFilename(comic.Filename) {
				ct = "novel"
			} else {
				ct = "comic"
			}
		}

		var tags []LibraryItemTag
		for _, t := range comic.Tags {
			tags = append(tags, LibraryItemTag{Name: t.Name, Color: t.Color})
		}
		if tags == nil {
			tags = []LibraryItemTag{}
		}

		items = append(items, LibraryItem{
			ID:             comic.ID,
			Title:          comic.Title,
			Filename:       comic.Filename,
			Author:         comic.Author,
			Genre:          comic.Genre,
			Description:    comic.Description,
			Year:           comic.Year,
			MetadataSource: comic.MetadataSource,
			HasMetadata:    hasMeta,
			ContentType:    ct,
			Tags:           tags,
		})
	}

	if items == nil {
		items = []LibraryItem{}
	}

	c.JSON(200, gin.H{
		"items":      items,
		"total":      result.Total,
		"page":       result.Page,
		"pageSize":   result.PageSize,
		"totalPages": result.TotalPages,
	})
}

// POST /api/metadata/batch-selected — 对选中项执行批量刮削 (SSE)
func (h *MetadataHandler) BatchSelected(c *gin.Context) {
	var body struct {
		ComicIDs    []string `json:"comicIds"`
		Lang        string   `json:"lang"`
		UpdateTitle bool     `json:"updateTitle"`
		Mode        string   `json:"mode"` // "standard" | "ai"
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body.ComicIDs) == 0 {
		c.JSON(400, gin.H{"error": "comicIds array required"})
		return
	}
	if body.Lang == "" {
		body.Lang = "en"
	}

	// 获取所有选中漫画的文件名
	type comicItem struct {
		ID       string
		Filename string
	}
	var comics []comicItem
	for _, id := range body.ComicIDs {
		detail, err := store.GetComicByID(id)
		if err != nil || detail == nil {
			continue
		}
		comics = append(comics, comicItem{ID: detail.ID, Filename: detail.Filename})
	}

	total := len(comics)
	if total == 0 {
		c.JSON(400, gin.H{"error": "No valid comics found"})
		return
	}

	// SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")
	c.Writer.Flush()

	sendSSE := func(data interface{}) {
		jsonData, _ := json.Marshal(data)
		fmt.Fprintf(c.Writer, "data: %s\n\n", string(jsonData))
		c.Writer.Flush()
	}

	sendSSE(gin.H{"type": "start", "total": total})

	// 检查 AI 配置（如果是 AI 模式）
	var aiCfg *service.AIConfig
	if body.Mode == "ai" {
		cfg := service.LoadAIConfig()
		if cfg.EnableCloudAI && cfg.CloudAPIKey != "" {
			aiCfg = &cfg
		}
	}

	success := 0
	failed := 0

	for i, comic := range comics {
		progress := gin.H{
			"type":     "progress",
			"current":  i + 1,
			"total":    total,
			"comicId":  comic.ID,
			"filename": comic.Filename,
		}

		isNovel := service.IsNovelFilename(comic.Filename)
		filePath := findComicFile(comic.Filename)

		// AI 模式：使用 AI 解析文件名
		if body.Mode == "ai" && aiCfg != nil {
			progress["step"] = "parse"
			sendSSE(progress)

			parsed, err := service.AIParseFilename(*aiCfg, comic.Filename)
			var searchQuery string
			if err == nil && parsed != nil && parsed.Title != "" {
				searchQuery = parsed.Title
				if parsed.Author != "" {
					searchQuery += " " + parsed.Author
				}
				progress["parsed"] = parsed
			} else {
				searchQuery = service.ExtractSearchQuery(comic.Filename)
			}

			if searchQuery != "" {
				progress["step"] = "search"
				sendSSE(progress)
				time.Sleep(1500 * time.Millisecond)

				ct := "comic"
				if isNovel {
					ct = "novel"
				}
				results := service.SearchMetadata(searchQuery, nil, body.Lang, ct)
				if len(results) > 0 {
					_, err := service.ApplyMetadata(comic.ID, results[0], body.Lang, body.UpdateTitle)
					if err == nil {
						progress["status"] = "success"
						progress["step"] = "done"
						progress["source"] = results[0].Source
						progress["matchTitle"] = results[0].Title
						sendSSE(progress)
						success++
						continue
					}
				}

				// AI 补全回退
				progress["step"] = "ai-complete"
				sendSSE(progress)

				detail, _ := store.GetComicByID(comic.ID)
				title := comic.Filename
				if detail != nil && detail.Title != "" {
					title = detail.Title
				}
				var coverData []byte
				if cb, err := service.GetComicThumbnail(comic.ID); err == nil {
					coverData = cb
				}
				meta, err := service.AICompleteMetadata(*aiCfg, comic.Filename, title, coverData, body.Lang)
				if err == nil && meta != nil {
					updates := map[string]interface{}{}
					if meta.Title != "" && body.UpdateTitle {
						updates["title"] = meta.Title
					}
					if meta.Author != "" {
						updates["author"] = meta.Author
					}
					if meta.Genre != "" {
						updates["genre"] = meta.Genre
					}
					if meta.Description != "" {
						updates["description"] = meta.Description
					}
					if meta.Language != "" {
						updates["language"] = meta.Language
					}
					if meta.Year != nil {
						updates["year"] = *meta.Year
					}
					if len(updates) > 0 {
						updates["metadataSource"] = "ai_complete"
						_ = store.UpdateComicFields(comic.ID, updates)
					}
					if meta.Tags != "" {
						var tags []string
						for _, t := range strings.Split(meta.Tags, ",") {
							t = strings.TrimSpace(t)
							if t != "" {
								tags = append(tags, t)
							}
						}
						if len(tags) > 0 {
							_ = store.AddTagsToComic(comic.ID, tags)
						}
					}
					progress["status"] = "success"
					progress["step"] = "done"
					progress["source"] = "ai_complete"
					sendSSE(progress)
					success++
					continue
				}
			}

			progress["status"] = "failed"
			progress["step"] = "done"
			progress["message"] = "No metadata found"
			sendSSE(progress)
			failed++
			continue
		}

		// 标准模式
		// 尝试本地提取
		if isNovel && filePath != "" {
			ext := strings.ToLower(filepath.Ext(comic.Filename))
			if ext == ".epub" {
				epubMeta, err := service.ExtractEpubMetadata(filePath)
				if err == nil && epubMeta != nil && epubMeta.Title != "" {
					_, err := service.ApplyMetadata(comic.ID, *epubMeta, body.Lang, body.UpdateTitle)
					if err == nil {
						progress["status"] = "success"
						progress["source"] = "epub_opf"
						if body.UpdateTitle && epubMeta.Title != "" {
							progress["matchTitle"] = epubMeta.Title
						}
						sendSSE(progress)
						success++
						continue
					}
				}
			}
		}

		if !isNovel && filePath != "" {
			comicInfo, _ := service.ExtractComicInfoFromArchive(filePath)
			if comicInfo != nil && comicInfo.Title != "" {
				_, err := service.ApplyMetadata(comic.ID, *comicInfo, body.Lang, body.UpdateTitle)
				if err == nil {
					progress["status"] = "success"
					progress["source"] = "comicinfo"
					if body.UpdateTitle && comicInfo.Title != "" {
						progress["matchTitle"] = comicInfo.Title
					}
					sendSSE(progress)
					success++
					continue
				}
			}
		}

		// 在线搜索
		searchQuery := service.ExtractSearchQuery(comic.Filename)
		if searchQuery == "" {
			progress["status"] = "skipped"
			progress["message"] = "No search query"
			sendSSE(progress)
			failed++
			continue
		}

		time.Sleep(1500 * time.Millisecond)
		ct := "comic"
		if isNovel {
			ct = "novel"
		}
		results := service.SearchMetadata(searchQuery, nil, body.Lang, ct)
		if len(results) > 0 {
			_, err := service.ApplyMetadata(comic.ID, results[0], body.Lang, body.UpdateTitle)
			if err == nil {
				progress["status"] = "success"
				progress["source"] = results[0].Source
				if body.UpdateTitle && results[0].Title != "" {
					progress["matchTitle"] = results[0].Title
				}
				sendSSE(progress)
				success++
				continue
			}
		}

		progress["status"] = "failed"
		progress["message"] = "No metadata found"
		sendSSE(progress)
		failed++
	}

	sendSSE(gin.H{
		"type":    "complete",
		"total":   total,
		"success": success,
		"failed":  failed,
	})
}

// POST /api/metadata/clear — 清除选中项的元数据
func (h *MetadataHandler) ClearMetadata(c *gin.Context) {
	var body struct {
		ComicIDs []string `json:"comicIds"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body.ComicIDs) == 0 {
		c.JSON(400, gin.H{"error": "comicIds array required"})
		return
	}

	cleared := 0
	for _, id := range body.ComicIDs {
		err := store.UpdateComicFields(id, map[string]interface{}{
			"author":         "",
			"publisher":      "",
			"description":    "",
			"genre":          "",
			"language":       "",
			"metadataSource": "",
			"coverImageUrl":  "",
		})
		if err == nil {
			cleared++
		}
	}

	c.JSON(200, gin.H{"success": true, "cleared": cleared})
}

// Helper: find comic file on disk across all comic directories.
func findComicFile(filename string) string {
	for _, dir := range config.GetAllComicsDirs() {
		fp := filepath.Join(dir, filename)
		if _, err := os.Stat(fp); err == nil {
			return fp
		}
	}
	return ""
}
