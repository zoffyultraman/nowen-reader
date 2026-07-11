package store

import "strings"

func init() {
	Migrations = append(Migrations, Migration{
		Version:     31,
		Description: "Remove mixed library type and restrict libraries to comic or novel",
		SQL: strings.Join([]string{
			// 历史 mixed 书库不直接丢弃：仅包含小说内容的书库迁移为 novel，
			// 空书库、漫画书库以及同时包含两类内容的书库统一迁移为 comic。
			`UPDATE "Library"
			 SET "type" = CASE
			 	WHEN EXISTS (
			 		SELECT 1 FROM "Comic" c
			 		WHERE c."libraryId" = "Library"."id" AND c."type" = 'novel'
			 	)
			 	AND NOT EXISTS (
			 		SELECT 1 FROM "Comic" c
			 		WHERE c."libraryId" = "Library"."id" AND c."type" = 'comic'
			 	)
			 	THEN 'novel'
			 	ELSE 'comic'
			 END
			 WHERE "type" NOT IN ('comic', 'novel');`,
			`CREATE TRIGGER IF NOT EXISTS "Library_type_insert_check"
			 BEFORE INSERT ON "Library"
			 WHEN NEW."type" NOT IN ('comic', 'novel')
			 BEGIN
			 	SELECT RAISE(ABORT, 'library type must be comic or novel');
			 END;`,
			`CREATE TRIGGER IF NOT EXISTS "Library_type_update_check"
			 BEFORE UPDATE OF "type" ON "Library"
			 WHEN NEW."type" NOT IN ('comic', 'novel')
			 BEGIN
			 	SELECT RAISE(ABORT, 'library type must be comic or novel');
			 END;`,
		}, "\n"),
	})
}
