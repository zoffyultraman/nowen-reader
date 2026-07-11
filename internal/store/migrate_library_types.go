package store

import "strings"

func init() {
	Migrations = append(Migrations, Migration{
		Version:     31,
		Description: "Remove mixed library type and restrict libraries to comic or novel",
		SQL: strings.Join([]string{
			// 历史 mixed 书库不直接丢弃：小说内容数量更多时迁移为 novel，
			// 其余情况（漫画更多、数量相同或空书库）迁移为 comic。
			`UPDATE "Library"
			 SET "type" = CASE
			 	WHEN (
			 		SELECT COUNT(*) FROM "Comic" c
			 		WHERE c."libraryId" = "Library"."id" AND c."type" = 'novel'
			 	) > (
			 		SELECT COUNT(*) FROM "Comic" c
			 		WHERE c."libraryId" = "Library"."id" AND c."type" = 'comic'
			 	)
			 	THEN 'novel'
			 	ELSE 'comic'
			 END
			 WHERE "type" NOT IN ('comic', 'novel');`,
			`CREATE TRIGGER IF NOT EXISTS "Library_type_insert_check"
			 BEFORE INSERT ON "Library"
			 WHEN NEW."type" NOT IN ('comic', 'novel') BEGIN
			 	SELECT RAISE(ABORT, 'library type must be comic or novel');
			 END;`,
			`CREATE TRIGGER IF NOT EXISTS "Library_type_update_check"
			 BEFORE UPDATE OF "type" ON "Library"
			 WHEN NEW."type" NOT IN ('comic', 'novel') BEGIN
			 	SELECT RAISE(ABORT, 'library type must be comic or novel');
			 END;`,
		}, "\n"),
	})
}
