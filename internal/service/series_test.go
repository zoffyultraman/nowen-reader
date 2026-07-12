package service

import (
	"testing"

	"github.com/nowen-reader/nowen-reader/internal/store"
)

func TestDetectComicSeriesDirectVolumes(t *testing.T) {
	items := []store.SeriesSourceItem{
		{ID: "comic-10", Title: "漂亮干姐姐 10", RelativePath: "P 漂亮干姐姐/漂亮干姐姐 10.pdf"},
		{ID: "comic-2", Title: "漂亮干姐姐 02", RelativePath: "P 漂亮干姐姐/漂亮干姐姐 02.pdf"},
		{ID: "comic-1", Title: "漂亮干姐姐 01", RelativePath: "P 漂亮干姐姐/漂亮干姐姐 01.pdf"},
	}

	series := DetectComicSeries("comic-library", items)
	if len(series) != 1 {
		t.Fatalf("series count = %d, want 1", len(series))
	}
	got := series[0]
	if got.Title != "P 漂亮干姐姐" || got.RootRelativePath != "P 漂亮干姐姐" {
		t.Fatalf("unexpected series identity: %#v", got)
	}
	if len(got.Sections) != 0 || len(got.Items) != 3 {
		t.Fatalf("sections=%d items=%d, want 0/3", len(got.Sections), len(got.Items))
	}
	wantOrder := []string{"comic-1", "comic-2", "comic-10"}
	for index, want := range wantOrder {
		if got.Items[index].ComicID != want || got.Items[index].SortIndex != index {
			t.Fatalf("item %d = %#v, want comic=%s sort=%d", index, got.Items[index], want, index)
		}
	}
}

func TestDetectComicSeriesSeasonsAndUnsectioned(t *testing.T) {
	items := []store.SeriesSourceItem{
		{ID: "special", Title: "暗箱 番外", RelativePath: "A 暗箱/暗箱 番外.pdf"},
		{ID: "s2", Title: "暗箱 01", RelativePath: "A 暗箱/第二季/暗箱 01.pdf"},
		{ID: "s1", Title: "暗箱 01", RelativePath: "A 暗箱/第一季/暗箱 01.pdf"},
	}

	series := DetectComicSeries("comic-library", items)
	if len(series) != 1 {
		t.Fatalf("series count = %d, want 1", len(series))
	}
	got := series[0]
	if len(got.Sections) != 2 {
		t.Fatalf("section count = %d, want 2", len(got.Sections))
	}
	if got.Sections[0].Title != "第一季" || got.Sections[1].Title != "第二季" {
		t.Fatalf("unexpected section order: %#v", got.Sections)
	}
	if len(got.Items) != 3 || got.Items[0].ComicID != "special" || got.Items[0].SectionID != "" {
		t.Fatalf("direct item should remain unsectioned: %#v", got.Items)
	}
}

func TestDetectComicSeriesImageFolderBoundaries(t *testing.T) {
	items := []store.SeriesSourceItem{
		{ID: "single-folder", Title: "单本图片漫画", RelativePath: "单本图片漫画/"},
		{ID: "chapter-2", Title: "第02话", RelativePath: "作品名/第02话/"},
		{ID: "chapter-1", Title: "第01话", RelativePath: "作品名/第01话/"},
	}

	series := DetectComicSeries("comic-library", items)
	if len(series) != 1 {
		t.Fatalf("series count = %d, want 1", len(series))
	}
	if series[0].RootRelativePath != "作品名" || len(series[0].Items) != 2 {
		t.Fatalf("unexpected image-folder series: %#v", series[0])
	}
	for _, item := range series[0].Items {
		if item.ComicID == "single-folder" {
			t.Fatal("a direct image-folder comic must remain standalone")
		}
	}
}

func TestDetectComicSeriesKeepsSingleItemStandalone(t *testing.T) {
	items := []store.SeriesSourceItem{
		{ID: "only", Title: "暗箱 01", RelativePath: "A 暗箱/第一季/暗箱 01.pdf"},
	}
	if series := DetectComicSeries("comic-library", items); len(series) != 0 {
		t.Fatalf("single item should remain standalone, got %#v", series)
	}
}
