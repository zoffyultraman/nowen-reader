package service

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/nowen-reader/nowen-reader/internal/model"
	"github.com/nowen-reader/nowen-reader/internal/store"
)

func setupScannerTestDB(t *testing.T) {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "scanner.db")
	if err := store.InitDB(dbPath); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.CloseDB() })
}

func TestQuickSyncIndexesNestedFileOnce(t *testing.T) {
	setupScannerTestDB(t)
	root := t.TempDir()
	novelRoot := filepath.Join(root, "novels")
	if err := os.MkdirAll(novelRoot, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(novelRoot, "book.epub"), []byte("epub"), 0644); err != nil {
		t.Fatal(err)
	}

	for _, lib := range []*model.Library{
		{ID: "parent", Name: "Parent", Type: "mixed", RootPath: root, Enabled: true, ScanEnabled: true},
		{ID: "novels", Name: "Novels", Type: "novel", RootPath: novelRoot, Enabled: true, ScanEnabled: true},
	} {
		if err := store.CreateLibrary(lib); err != nil {
			t.Fatal(err)
		}
	}

	added, removed := quickSync()
	if added != 1 || removed != 0 {
		t.Fatalf("quickSync added=%d removed=%d", added, removed)
	}
	var count int
	if err := store.DB().QueryRow(`SELECT COUNT(*) FROM "Comic"`).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 1 {
		t.Fatalf("expected one indexed row, got %d", count)
	}
	var libraryID, comicType string
	if err := store.DB().QueryRow(`SELECT "libraryId", "type" FROM "Comic"`).Scan(&libraryID, &comicType); err != nil {
		t.Fatal(err)
	}
	if libraryID != "novels" || comicType != "novel" {
		t.Fatalf("book indexed as library=%s type=%s", libraryID, comicType)
	}
}

func TestQuickSyncSkipsExactRootConflict(t *testing.T) {
	setupScannerTestDB(t)
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "book.epub"), []byte("epub"), 0644); err != nil {
		t.Fatal(err)
	}
	for _, lib := range []*model.Library{
		{ID: "one", Name: "One", Type: "novel", RootPath: root, Enabled: true, ScanEnabled: true},
		{ID: "two", Name: "Two", Type: "novel", RootPath: root, Enabled: true, ScanEnabled: true},
	} {
		if err := store.CreateLibrary(lib); err != nil {
			t.Fatal(err)
		}
	}

	added, removed := quickSync()
	if added != 0 || removed != 0 {
		t.Fatalf("conflicting roots must not scan: added=%d removed=%d", added, removed)
	}
}

func TestOwnershipReconcileMergesSamePhysicalFile(t *testing.T) {
	setupScannerTestDB(t)
	root := t.TempDir()
	novelRoot := filepath.Join(root, "novels")
	if err := os.MkdirAll(novelRoot, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(novelRoot, "book.epub"), []byte("epub"), 0644); err != nil {
		t.Fatal(err)
	}
	for _, lib := range []*model.Library{
		{ID: "parent", Name: "Parent", Type: "mixed", RootPath: root, Enabled: true, ScanEnabled: true},
		{ID: "novels", Name: "Novels", Type: "novel", RootPath: novelRoot, Enabled: true, ScanEnabled: true},
	} {
		if err := store.CreateLibrary(lib); err != nil {
			t.Fatal(err)
		}
	}

	parentID := store.PathToID("parent", "novels/book.epub")
	childID := store.PathToID("novels", "book.epub")
	now := time.Now().UTC()
	for _, row := range []struct {
		id, filename, libraryID string
	}{
		{parentID, "novels/book.epub", "parent"},
		{childID, "book.epub", "novels"},
	} {
		if _, err := store.DB().Exec(`
			INSERT INTO "Comic" ("id", "filename", "title", "pageCount", "fileSize", "type", "libraryId", "relativePath", "addedAt", "updatedAt")
			VALUES (?, ?, 'Book', 1, 4, 'novel', ?, ?, ?, ?)
		`, row.id, row.filename, row.libraryID, row.filename, now, now); err != nil {
			t.Fatal(err)
		}
	}

	preview, err := PreviewLibraryOwnership()
	if err != nil {
		t.Fatal(err)
	}
	if preview.IssueCount != 1 || preview.DuplicateRows != 1 || !preview.CanReconcile {
		t.Fatalf("unexpected preview: %#v", preview)
	}
	result, err := ReconcileLibraryOwnership()
	if err != nil {
		t.Fatal(err)
	}
	if result.Reconciled != 1 || result.MergedRows != 1 {
		t.Fatalf("unexpected reconcile result: %#v", result)
	}

	var count int
	var gotID, gotLibrary, gotPath string
	if err := store.DB().QueryRow(`SELECT COUNT(*), "id", "libraryId", "relativePath" FROM "Comic"`).Scan(&count, &gotID, &gotLibrary, &gotPath); err != nil {
		t.Fatal(err)
	}
	if count != 1 || gotID != childID || gotLibrary != "novels" || gotPath != "book.epub" {
		t.Fatalf("unexpected canonical row: count=%d id=%s library=%s path=%s", count, gotID, gotLibrary, gotPath)
	}
}

func TestOwnershipReconcileRequiresExplicitExactRootOwner(t *testing.T) {
	setupScannerTestDB(t)
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "book.epub"), []byte("epub"), 0644); err != nil {
		t.Fatal(err)
	}
	for _, lib := range []*model.Library{
		{ID: "one", Name: "One", Type: "novel", RootPath: root, Enabled: true, ScanEnabled: true},
		{ID: "two", Name: "Two", Type: "novel", RootPath: root, Enabled: true, ScanEnabled: true},
	} {
		if err := store.CreateLibrary(lib); err != nil {
			t.Fatal(err)
		}
	}
	now := time.Now().UTC()
	for _, libraryID := range []string{"one", "two"} {
		id := store.PathToID(libraryID, "book.epub")
		if _, err := store.DB().Exec(`
			INSERT INTO "Comic" ("id", "filename", "title", "pageCount", "fileSize", "type", "libraryId", "relativePath", "addedAt", "updatedAt")
			VALUES (?, 'book.epub', 'Book', 1, 4, 'novel', ?, 'book.epub', ?, ?)
		`, id, libraryID, now, now); err != nil {
			t.Fatal(err)
		}
	}

	preview, err := PreviewLibraryOwnership()
	if err != nil {
		t.Fatal(err)
	}
	if len(preview.RootConflicts) != 1 || preview.CanReconcile {
		t.Fatalf("unexpected unresolved preview: %#v", preview)
	}
	if result, err := ReconcileLibraryOwnership(); err == nil || result == nil || result.Blocked != 1 {
		t.Fatalf("reconcile without owner should be blocked: result=%#v err=%v", result, err)
	}

	result, err := ReconcileLibraryOwnership(map[string]string{root: "two"})
	if err != nil {
		t.Fatal(err)
	}
	if result.Reconciled != 1 || result.MergedRows != 1 {
		t.Fatalf("unexpected reconcile result: %#v", result)
	}
	var count int
	var libraryID string
	if err := store.DB().QueryRow(`SELECT COUNT(*), "libraryId" FROM "Comic"`).Scan(&count, &libraryID); err != nil {
		t.Fatal(err)
	}
	if count != 1 || libraryID != "two" {
		t.Fatalf("unexpected exact-root owner: count=%d library=%s", count, libraryID)
	}
}
