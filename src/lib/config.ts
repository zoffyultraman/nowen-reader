import path from "path";

// 漫画库目录 - 用户将漫画 zip/cbz 文件放在此目录下
// 可通过环境变量 COMICS_DIR 覆盖
export const COMICS_DIR =
  process.env.COMICS_DIR || path.join(process.cwd(), "comics");

// 缩略图缓存目录
export const THUMBNAILS_DIR = path.join(process.cwd(), ".cache", "thumbnails");

// 支持的压缩包格式
export const SUPPORTED_EXTENSIONS = [".zip", ".cbz", ".cbr", ".rar", ".7z", ".cb7", ".pdf"];

// 支持的图片格式（压缩包内的文件）
export const IMAGE_EXTENSIONS = [
  ".jpg",
  ".jpeg",
  ".png",
  ".gif",
  ".webp",
  ".bmp",
  ".avif",
];

// 缩略图尺寸
export const THUMBNAIL_WIDTH = 400;
export const THUMBNAIL_HEIGHT = 560;
