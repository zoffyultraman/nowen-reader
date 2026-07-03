package store

import (
	"log"
	"path"
	"strings"
)

// ============================================================
// 按目录自动分组 — 扫描后自动将同文件夹下的书籍归为合集
// ============================================================

// chapterKeywords 话级关键词（保留用于向后兼容）
var chapterKeywords = []string{
	"第", "话", "話", "回", "chapter", "ch.", "ch ", "ep", "episode", "#",
}

// IsChapterNaming 判断文件名是否符合按话命名模式（保留用于向后兼容）。
func IsChapterNaming(filename string) bool {
	lower := strings.ToLower(filename)
	for _, kw := range chapterKeywords {
		if strings.Contains(lower, kw) {
			return true
		}
	}
	return false
}

// AutoGroupByDirectory 按文件夹自动创建目录合集。
// 规则：同一文件夹下有 2 本及以上未分组的书籍时，自动创建为合集。
// 不再限制文件名必须包含章节关键词，支持小说、漫画等所有类型。
func AutoGroupByDirectory() (int, error) {
	grouped, err := GetGroupedComicIDs()
	if err != nil {
		return 0, err
	}

	// 查询所有未分组的书籍（包括漫画和小说）
	rows, err := db.Query(`SELECT "id", "title", "filename" FROM "Comic" ` + TitleSortOrderSQL("", "ASC"))
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	type comicRef struct {
		ID       string
		Title    string
		Filename string
	}

	dirMap := make(map[string][]comicRef)
	for rows.Next() {
		var id, title, filename string
		if rows.Scan(&id, &title, &filename) != nil {
			continue
		}
		// 跳过已分组的书籍
		if _, ok := grouped[id]; ok {
			continue
		}
		// 提取父目录路径
		dir := path.Dir(filename)
		if dir == "." || dir == "/" || dir == "" {
			continue // 根目录下的文件不参与自动分组
		}
		dirMap[dir] = append(dirMap[dir], comicRef{ID: id, Title: title, Filename: filename})
	}

	created := 0
	for dir, refs := range dirMap {
		// 核心规则：同一文件夹下有 2 本及以上才创建合集
		if len(refs) < 2 {
			continue
		}

		// 使用 cleanDirName 提取可读的组名
		groupName := cleanDirName(path.Base(dir))
		if groupName == "" {
			continue
		}

		// 收集所有书籍 ID
		var ids []string
		for _, ref := range refs {
			ids = append(ids, ref.ID)
		}

		// 检查是否已存在同名分组
		var existingID int
		err := db.QueryRow(`SELECT "id" FROM "ComicGroup" WHERE "name" = ?`, groupName).Scan(&existingID)
		if err == nil {
			// 已存在同名分组，将新书籍添加进去
			if addErr := AddComicsToGroup(existingID, ids); addErr != nil {
				log.Printf("[auto-group] 添加书籍到合集 %s 失败: %v", groupName, addErr)
			} else {
				created++
			}
			continue
		}

		// 创建新合集
		id, createErr := CreateGroup(groupName)
		if createErr != nil {
			log.Printf("[auto-group] 创建合集 %s 失败: %v", groupName, createErr)
			continue
		}

		// 标记为自动创建
		if _, execErr := db.Exec(`UPDATE "ComicGroup" SET "autoCreated" = 1, "classifyMode" = 'directory' WHERE "id" = ?`, id); execErr != nil {
			log.Printf("[auto-group] 标记合集 %s 失败: %v", groupName, execErr)
		}

		// 将书籍添加到合集
		if addErr := AddComicsToGroup(int(id), ids); addErr != nil {
			log.Printf("[auto-group] 添加书籍到合集 %s 失败: %v", groupName, addErr)
			continue
		}

		// 自动继承第一本书的元数据
		if inheritErr := InheritGroupMetadataFromFirstComic(int(id)); inheritErr != nil {
			log.Printf("[auto-group] 继承元数据失败 %s: %v", groupName, inheritErr)
		}

		created++
		log.Printf("[auto-group] 按目录自动创建合集: %s (%d 本)", groupName, len(refs))
	}

	return created, nil
}

// Tag 是从 model 包复制的简化版本，避免循环依赖。
type Tag struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Color string `json:"color"`
}
