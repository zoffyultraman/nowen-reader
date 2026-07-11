package store

import (
	"fmt"
	"path"
	"strings"
)

// ComicSourceIdentity identifies a scanned source independently from the
// database row ID. It is used to keep record-only deletions hidden while the
// physical file remains on disk.
type ComicSourceIdentity struct {
	ID           string
	LibraryID    string
	RelativePath string
}

// GetComicSourceIdentities returns the library-relative identities for the
// requested comic rows. Missing IDs are ignored.
func GetComicSourceIdentities(ids []string) ([]ComicSourceIdentity, error) {
	unique := make([]string, 0, len(ids))
	seen := make(map[string]struct{}, len(ids))
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		unique = append(unique, id)
	}
	if len(unique) == 0 {
		return []ComicSourceIdentity{}, nil
	}

	placeholders := make([]string, len(unique))
	args := make([]interface{}, len(unique))
	for i, id := range unique {
		placeholders[i] = "?"
		args[i] = id
	}

	rows, err := db.Query(fmt.Sprintf(`
		SELECT "id", COALESCE("libraryId", ''), COALESCE(NULLIF("relativePath", ''), "filename")
		FROM "Comic"
		WHERE "id" IN (%s)
	`, strings.Join(placeholders, ",")), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]ComicSourceIdentity, 0, len(unique))
	for rows.Next() {
		var item ComicSourceIdentity
		if err := rows.Scan(&item.ID, &item.LibraryID, &item.RelativePath); err != nil {
			return nil, err
		}
		normalized, err := normalizeIgnoredRelativePath(item.RelativePath)
		if err != nil || item.LibraryID == "" {
			continue
		}
		item.RelativePath = normalized
		result = append(result, item)
	}
	return result, rows.Err()
}

// AddIgnoredLibraryContents stores tombstones for record-only deletions.
// Automatic scans are blocked by the migration-installed Comic insert trigger.
func AddIgnoredLibraryContents(items []ComicSourceIdentity) error {
	return updateIgnoredLibraryContents(items, true)
}

// RemoveIgnoredLibraryContents removes tombstones, primarily used to roll back
// a failed delete request.
func RemoveIgnoredLibraryContents(items []ComicSourceIdentity) error {
	return updateIgnoredLibraryContents(items, false)
}

func updateIgnoredLibraryContents(items []ComicSourceIdentity, ignored bool) error {
	if len(items) == 0 {
		return nil
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	seen := make(map[string]struct{}, len(items))
	for _, item := range items {
		libraryID := strings.TrimSpace(item.LibraryID)
		relativePath, normalizeErr := normalizeIgnoredRelativePath(item.RelativePath)
		if normalizeErr != nil || libraryID == "" {
			continue
		}
		key := libraryID + "\x00" + relativePath
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}

		if ignored {
			if _, err := tx.Exec(`
				INSERT INTO "LibraryIgnoredContent" ("libraryId", "relativePath")
				VALUES (?, ?)
				ON CONFLICT("libraryId", "relativePath") DO NOTHING
			`, libraryID, relativePath); err != nil {
				return err
			}
		} else {
			if _, err := tx.Exec(`
				DELETE FROM "LibraryIgnoredContent"
				WHERE "libraryId" = ? AND "relativePath" = ?
			`, libraryID, relativePath); err != nil {
				return err
			}
		}
	}

	return tx.Commit()
}

func normalizeIgnoredRelativePath(value string) (string, error) {
	raw := strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if raw == "" {
		return "", fmt.Errorf("relative path is empty")
	}
	isDirectory := strings.HasSuffix(raw, "/")
	cleaned := path.Clean(raw)
	if cleaned == "." || cleaned == ".." || path.IsAbs(cleaned) || strings.HasPrefix(cleaned, "../") {
		return "", fmt.Errorf("invalid relative path: %s", value)
	}
	if isDirectory {
		cleaned += "/"
	}
	return cleaned, nil
}
