package store

import (
	"testing"
)

func TestRunMigrations(t *testing.T) {
	setupTestDB(t)

	// Run migrations should succeed on fresh database
	if err := RunMigrations(); err != nil {
		t.Fatalf("RunMigrations failed: %v", err)
	}

	// Running again should be idempotent (no error)
	if err := RunMigrations(); err != nil {
		t.Fatalf("RunMigrations (idempotent) failed: %v", err)
	}

	// Verify migrations table exists and has entries
	var count int
	err := DB().QueryRow(`SELECT COUNT(*) FROM "_migrations"`).Scan(&count)
	if err != nil {
		t.Fatalf("Failed to query migrations table: %v", err)
	}
	if count != len(Migrations) {
		t.Errorf("Expected %d migrations recorded, got %d", len(Migrations), count)
	}
}

func TestSplitSQL(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected int
	}{
		{"single statement", "SELECT 1;", 1},
		{"two statements on separate lines", "SELECT 1;\nSELECT 2;", 2},
		{"empty string", "", 0},
		{"only whitespace and semicolons", "  ;  ;  ", 0},
		{"alter and create index on separate lines", "ALTER TABLE x ADD COLUMN y;\nCREATE INDEX idx ON x(y);", 2},
		{"trigger with internal semicolons", "CREATE TRIGGER t AFTER INSERT ON x BEGIN INSERT INTO y VALUES (1); END", 1},
		{"virtual table then trigger", "CREATE VIRTUAL TABLE ft USING fts5(a);\nCREATE TRIGGER t AFTER INSERT ON x BEGIN INSERT INTO y VALUES (1); END", 2},
		{"multiple triggers", "CREATE TRIGGER t1 AFTER INSERT ON x BEGIN INSERT INTO y VALUES (1); END\nCREATE TRIGGER t2 AFTER DELETE ON x BEGIN INSERT INTO y VALUES (2); END", 2},
		{"trigger with multiple internal statements", "CREATE TRIGGER t AFTER UPDATE ON x BEGIN DELETE FROM y WHERE id=old.id; INSERT INTO y VALUES (new.id); END", 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := splitSQL(tt.input)
			if len(result) != tt.expected {
				t.Errorf("splitSQL(%q) = %d parts %v, expected %d", tt.input, len(result), result, tt.expected)
			}
		})
	}
}

func TestIsIgnorableError(t *testing.T) {
	tests := []struct {
		msg       string
		ignorable bool
	}{
		{"duplicate column name: coverImageUrl", true},
		{"table User already exists", true},
		{"index already exists", true},
		{"UNIQUE constraint failed", false},
		{"syntax error", false},
	}

	for _, tt := range tests {
		err := &testError{msg: tt.msg}
		result := isIgnorableError(err)
		if result != tt.ignorable {
			t.Errorf("isIgnorableError(%q) = %v, expected %v", tt.msg, result, tt.ignorable)
		}
	}
}

type testError struct {
	msg string
}

func (e *testError) Error() string {
	return e.msg
}

func TestMigrateFromPrismaDBNotFound(t *testing.T) {
	setupTestDB(t)

	err := MigrateFromPrismaDB("/nonexistent/path/db.sqlite")
	if err == nil {
		t.Error("Expected error for nonexistent Prisma database")
	}
}
