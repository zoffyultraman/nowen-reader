# NowenReader

> 现代化的本地漫画管理与阅读工具 | A modern local comic management and reading tool

---

## 中文文档

### 简介

NowenReader 是一款基于 Next.js 16 全栈开发的本地漫画阅读器。将漫画压缩包放入 `comics/` 目录或通过 Web 上传，系统自动扫描解析、生成缩略图并入库管理。支持书架浏览、多种阅读模式和完整的元数据管理。

### 技术栈

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | Next.js (App Router) | 16.1.6 |
| UI | React | 19 |
| 样式 | Tailwind CSS | v4 |
| 语言 | TypeScript | 5 |
| ORM | Prisma (LibSQL 适配器) | 7 |
| 数据库 | SQLite | - |
| 图片处理 | Sharp | 0.34 |
| 压缩包解析 | adm-zip | 0.5 |

### 功能特性

#### 漫画库管理 (书架)

- **双视图模式**: 网格视图 (响应式 2-6 列) 和列表视图
- **搜索**: 按标题、标签模糊搜索
- **标签筛选**: 多标签 OR 筛选，10 种预设颜色
- **收藏过滤**: 一键切换仅显示收藏
- **排序**: 按标题 / 最近阅读 / 评分排序，支持升降序
- **文件上传**: 支持 `.zip` / `.cbz` / `.cbr` / `.rar` 格式
- **自动同步**: 自动扫描 `comics/` 目录，新增入库、删除清理

#### 漫画阅读器

- **三种阅读模式**:
  - 单页模式 — 点击左右翻页
  - 双页模式 — 双页并排，模拟实体书
  - 长条模式 — 上下滚动，适合条漫
- **阅读方向**: 左→右 (LTR) / 右→左 (RTL，日漫风格)
- **键盘快捷键**: ← → / A D 翻页, F 全屏, I 信息面板, Esc 返回
- **全屏阅读**: 支持浏览器全屏 API
- **进度保存**: 自动保存阅读进度，下次打开恢复到上次位置
- **页面滑块**: 底部拖动条快速跳页

#### 信息面板

- 收藏切换
- 1-5 星评分
- 标签管理 (添加/删除)
- 阅读进度展示

#### 后端服务

- **文件系统同步**: 每次请求自动扫描目录，保持数据库与文件一致
- **压缩包解析**: 智能过滤 macOS 元数据、自然排序页面
- **缩略图缓存**: Sharp 生成 400×560 WebP 封面，缓存到 `.cache/thumbnails/`
- **稳定 ID**: 基于文件名 MD5 哈希

### 快速开始

```bash
# 安装依赖
npm install

# 初始化数据库
npm run db:push

# 启动开发服务器
npm run dev
```

在浏览器中打开 [http://localhost:3000](http://localhost:3000)。

将漫画压缩包 (.zip / .cbz) 放入项目根目录的 `comics/` 文件夹，刷新页面即可自动识别。

### 脚本命令

| 命令 | 说明 |
|------|------|
| `npm run dev` | 启动开发服务器 |
| `npm run build` | 生产构建 (含 Prisma 生成 + Schema 推送) |
| `npm run start` | 启动生产服务器 |
| `npm run db:push` | 推送 Schema 到数据库 |
| `npm run db:studio` | 打开 Prisma Studio 数据库管理 |
| `npm run db:generate` | 生成 Prisma Client |

### 项目结构

```
nowen-reader/
├── comics/                  # 漫画文件存放目录
├── prisma/
│   └── schema.prisma        # 数据库模型定义
├── src/
│   ├── app/
│   │   ├── page.tsx         # 书架主页面
│   │   ├── reader/[id]/     # 阅读器页面
│   │   └── api/             # RESTful API 路由
│   ├── components/
│   │   ├── ComicCard.tsx    # 漫画卡片 (网格/列表)
│   │   ├── Navbar.tsx       # 导航栏
│   │   ├── StatsBar.tsx     # 统计栏
│   │   ├── TagFilter.tsx    # 标签筛选器
│   │   └── reader/          # 阅读器视图组件
│   ├── hooks/               # 自定义 Hooks
│   ├── lib/                 # 核心库 (数据库/解析器/服务)
│   └── types/               # TypeScript 类型定义
└── package.json
```

### API 接口

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/api/comics` | 获取漫画列表 (含自动同步) |
| GET | `/api/comics/[id]` | 获取漫画详情 |
| PUT | `/api/comics/[id]/favorite` | 切换收藏 |
| GET | `/api/comics/[id]/pages` | 获取页面列表 |
| PUT | `/api/comics/[id]/progress` | 更新阅读进度 |
| PUT | `/api/comics/[id]/rating` | 更新评分 |
| POST | `/api/comics/[id]/tags` | 添加标签 |
| DELETE | `/api/comics/[id]/tags` | 删除标签 |
| GET | `/api/comics/[id]/thumbnail` | 获取封面缩略图 |
| GET | `/api/comics/[id]/page/[pageIndex]` | 获取单页图片 |
| POST | `/api/upload` | 上传漫画文件 |
| GET | `/api/tags` | 获取所有标签 |

---

## English Documentation

### Introduction

NowenReader is a full-stack local comic reader built with Next.js 16. Drop comic archives into the `comics/` directory or upload via the web interface — the system automatically scans, parses, generates thumbnails, and catalogs your collection. Features a bookshelf browser, multiple reading modes, and comprehensive metadata management.

### Tech Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Framework | Next.js (App Router) | 16.1.6 |
| UI | React | 19 |
| Styling | Tailwind CSS | v4 |
| Language | TypeScript | 5 |
| ORM | Prisma (LibSQL adapter) | 7 |
| Database | SQLite | - |
| Image Processing | Sharp | 0.34 |
| Archive Parsing | adm-zip | 0.5 |

### Features

#### Comic Library (Bookshelf)

- **Dual View Modes**: Grid view (responsive 2-6 columns) and list view
- **Search**: Fuzzy search by title and tags
- **Tag Filtering**: Multi-tag OR filtering with 10 preset colors
- **Favorites Filter**: One-click toggle to show favorites only
- **Sorting**: By title / last read / rating, ascending or descending
- **File Upload**: Supports `.zip` / `.cbz` / `.cbr` / `.rar` formats
- **Auto Sync**: Automatically scans the `comics/` directory — new files are added, removed files are cleaned up

#### Comic Reader

- **Three Reading Modes**:
  - Single Page — click left/right to turn pages
  - Double Page — side-by-side spread, simulating a physical book
  - Webtoon — vertical scroll, ideal for web comics
- **Reading Direction**: LTR (left-to-right) / RTL (right-to-left, manga style)
- **Keyboard Shortcuts**: ← → / A D for page turn, F for fullscreen, I for info panel, Esc to go back
- **Fullscreen**: Browser Fullscreen API support
- **Progress Saving**: Auto-saves reading progress; resumes from last position
- **Page Slider**: Bottom drag bar for quick page navigation

#### Info Panel

- Favorite toggle
- 1-5 star rating
- Tag management (add/remove)
- Reading progress display

#### Backend Services

- **File System Sync**: Auto-scans directory on each request, keeping database consistent with files
- **Archive Parsing**: Smart filtering of macOS metadata, natural sort for page filenames
- **Thumbnail Cache**: Sharp generates 400×560 WebP covers, cached in `.cache/thumbnails/`
- **Stable IDs**: Based on filename MD5 hash

### Quick Start

```bash
# Install dependencies
npm install

# Initialize database
npm run db:push

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

Place comic archives (.zip / .cbz) in the `comics/` folder at the project root, then refresh the page to auto-detect them.

### Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Production build (includes Prisma generate + schema push) |
| `npm run start` | Start production server |
| `npm run db:push` | Push schema to database |
| `npm run db:studio` | Open Prisma Studio for database management |
| `npm run db:generate` | Generate Prisma Client |

### Project Structure

```
nowen-reader/
├── comics/                  # Comic files directory
├── prisma/
│   └── schema.prisma        # Database model definitions
├── src/
│   ├── app/
│   │   ├── page.tsx         # Bookshelf main page
│   │   ├── reader/[id]/     # Reader page
│   │   └── api/             # RESTful API routes
│   ├── components/
│   │   ├── ComicCard.tsx    # Comic card (grid/list)
│   │   ├── Navbar.tsx       # Navigation bar
│   │   ├── StatsBar.tsx     # Statistics bar
│   │   ├── TagFilter.tsx    # Tag filter
│   │   └── reader/          # Reader view components
│   ├── hooks/               # Custom Hooks
│   ├── lib/                 # Core libraries (DB/parser/service)
│   └── types/               # TypeScript type definitions
└── package.json
```

### API Reference

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/comics` | List comics (with auto sync) |
| GET | `/api/comics/[id]` | Get comic details |
| PUT | `/api/comics/[id]/favorite` | Toggle favorite |
| GET | `/api/comics/[id]/pages` | Get page list |
| PUT | `/api/comics/[id]/progress` | Update reading progress |
| PUT | `/api/comics/[id]/rating` | Update rating |
| POST | `/api/comics/[id]/tags` | Add tag |
| DELETE | `/api/comics/[id]/tags` | Remove tag |
| GET | `/api/comics/[id]/thumbnail` | Get cover thumbnail |
| GET | `/api/comics/[id]/page/[pageIndex]` | Get single page image |
| POST | `/api/upload` | Upload comic file |
| GET | `/api/tags` | Get all tags |

---

## 未来计划 / Roadmap

### 近期 / Short Term

- [ ] **批量操作** — 批量删除、批量添加标签、批量收藏  
  *Batch operations — bulk delete, bulk tag, bulk favorite*
- [ ] **阅读统计** — 阅读时长统计、阅读历史记录  
  *Reading statistics — reading time tracking, reading history*
- [ ] **漫画详情页** — 独立的漫画详情页面，展示完整元数据  
  *Comic detail page — dedicated page showing full metadata*
- [ ] **拖拽排序** — 支持书架自定义排列顺序  
  *Drag & drop sorting — custom bookshelf arrangement*
- [ ] **书架分组** — 按文件夹/系列分组管理  
  *Bookshelf grouping — organize by folder or series*

### 中期 / Mid Term

- [ ] **多语言支持** — i18n 国际化，支持中英日等多语言  
  *Internationalization — i18n support for Chinese, English, Japanese, etc.*
- [ ] **用户系统** — 多用户登录，独立的书架和阅读进度  
  *User system — multi-user login with independent bookshelf and progress*
- [ ] **OPDS 协议** — 支持 OPDS 目录协议，兼容其他阅读器  
  *OPDS protocol — support OPDS catalog for compatibility with other readers*
- [ ] **元数据刮削** — 自动从在线数据库获取漫画信息 (封面/作者/简介)  
  *Metadata scraping — auto-fetch comic info from online databases*
- [ ] **RAR/7z 支持** — 原生支持 RAR 和 7z 格式解析  
  *RAR/7z support — native parsing for RAR and 7z formats*
- [ ] **PDF 支持** — 支持 PDF 格式漫画阅读  
  *PDF support — read comics in PDF format*

### 远期 / Long Term

- [ ] **移动端适配** — PWA 支持，离线阅读，触摸手势  
  *Mobile adaptation — PWA support, offline reading, touch gestures*
- [ ] **Electron 桌面版** — 打包为独立桌面应用  
  *Electron desktop app — package as standalone desktop application*
- [ ] **云同步** — 跨设备同步阅读进度和书架  
  *Cloud sync — sync reading progress and bookshelf across devices*
- [ ] **智能推荐** — 基于阅读习惯的漫画推荐  
  *Smart recommendations — comic suggestions based on reading habits*
- [ ] **插件系统** — 支持第三方插件扩展功能  
  *Plugin system — extensible with third-party plugins*

---

## 许可证 / License

MIT
