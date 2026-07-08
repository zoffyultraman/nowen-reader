package archive

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"
)

func TestEpubReaderPrefersNCXOverSpine(t *testing.T) {
	fp := writeTestEpub(t, "converted-book.zip", map[string]string{
		"mimetype":               "application/epub+zip",
		"META-INF/container.xml": `<?xml version="1.0" encoding="UTF-8"?><container><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>`,
		"OEBPS/content.opf": `<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata><title>Converted</title></metadata>
  <manifest>
    <item href="text00000.html" id="id_1" media-type="application/xhtml+xml"/>
    <item href="text00001.html" id="id_2" media-type="application/xhtml+xml"/>
    <item href="text00002.html" id="id_3" media-type="application/xhtml+xml"/>
    <item href="text00003.html" id="id_4" media-type="application/xhtml+xml"/>
    <item href="text00004.html" id="id_5" media-type="application/xhtml+xml"/>
    <item href="text00005.html" id="id_6" media-type="application/xhtml+xml"/>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="id_1"/>
    <itemref idref="id_2"/>
    <itemref idref="id_3"/>
    <itemref idref="id_4"/>
    <itemref idref="id_5"/>
    <itemref idref="id_6"/>
  </spine>
</package>`,
		"OEBPS/toc.ncx": `<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="nav1" playOrder="1">
      <navLabel><text>第一章 正文开始</text></navLabel>
      <content src="text00003.html#start"/>
    </navPoint>
    <navPoint id="nav2" playOrder="2">
      <navLabel><text>第二章 嵌套父项</text></navLabel>
      <content src="text00004.html#start"/>
      <navPoint id="nav3" playOrder="3">
        <navLabel><text>第三章 嵌套子项</text></navLabel>
        <content src="text00005.html#start"/>
      </navPoint>
    </navPoint>
  </navMap>
</ncx>`,
		"OEBPS/text00000.html": testXHTML("empty-0", ""),
		"OEBPS/text00001.html": testXHTML("empty-1", ""),
		"OEBPS/text00002.html": testXHTML("empty-2", ""),
		"OEBPS/text00003.html": testXHTML("wrong title", "chapter one"),
		"OEBPS/text00004.html": testXHTML("wrong title", "chapter two"),
		"OEBPS/text00005.html": testXHTML("wrong title", "chapter three"),
	})

	if got := DetectType(fp); got != TypeEpub {
		t.Fatalf("DetectType() = %q, want %q", got, TypeEpub)
	}

	reader, err := NewReader(fp)
	if err != nil {
		t.Fatalf("NewReader() error = %v", err)
	}
	defer reader.Close()

	entries := reader.ListEntries()
	if len(entries) != 3 {
		t.Fatalf("ListEntries() length = %d, want 3", len(entries))
	}

	titles := GetEpubChapterTitles(reader)
	wantTitles := []string{"第一章 正文开始", "第二章 嵌套父项", "第三章 嵌套子项"}
	if len(titles) != len(wantTitles) {
		t.Fatalf("GetEpubChapterTitles() length = %d, want %d: %v", len(titles), len(wantTitles), titles)
	}
	for i, want := range wantTitles {
		if titles[i] != want {
			t.Fatalf("title[%d] = %q, want %q", i, titles[i], want)
		}
	}
}

func writeTestEpub(t *testing.T, name string, files map[string]string) string {
	t.Helper()

	fp := filepath.Join(t.TempDir(), name)
	f, err := os.Create(fp)
	if err != nil {
		t.Fatalf("create epub: %v", err)
	}
	defer f.Close()

	zw := zip.NewWriter(f)
	for name, content := range files {
		w, err := zw.Create(name)
		if err != nil {
			t.Fatalf("create zip entry %s: %v", name, err)
		}
		if _, err := w.Write([]byte(content)); err != nil {
			t.Fatalf("write zip entry %s: %v", name, err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return fp
}

func testXHTML(title, body string) string {
	return `<?xml version="1.0" encoding="UTF-8"?><html><head><title>` + title + `</title></head><body><p>` + body + `</p></body></html>`
}
