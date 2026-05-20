"""
P0-1 + 清理: JPG → PNG 批量转换 + 死资源清理
杨奇监修 — 暗而不黑基调保持，边缘Alpha处理
用法: python convert_jpg_to_png.py
依赖: pip install pillow
"""
import os
import sys
from PIL import Image

GEN_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "generated")

FILES = [
    "icon_slash", "icon_lightning", "icon_aoe", "icon_multi_shot",
    "icon_whirlwind", "icon_snipe", "icon_ice", "icon_fire", "icon_shadow",
    "weapon_sword", "weapon_bow", "weapon_staff",
]

EDGE_THRESHOLD = 8  # 纯黑(<8)或纯白(>247)边缘像素 → Alpha 0


def is_edge_pixel(x: int, y: int, w: int, h: int) -> bool:
    """判断像素是否位于图像边缘（最外层1px）"""
    return x == 0 or y == 0 or x == w - 1 or y == h - 1


def should_make_transparent(r: int, g: int, b: int) -> bool:
    """纯黑或纯白边缘像素应当透明"""
    if r <= EDGE_THRESHOLD and g <= EDGE_THRESHOLD and b <= EDGE_THRESHOLD:
        return True
    if r >= 255 - EDGE_THRESHOLD and g >= 255 - EDGE_THRESHOLD and b >= 255 - EDGE_THRESHOLD:
        return True
    return False


def apply_dark_but_not_black(img) -> object:
    """
    暗而不黑: 确保暗色区域有层次感，不死黑一团。
    将纯黑(0,0,0)像素提升到深色基线 (10, 10, 20)，保留纹理层次。
    深空基调 #0a0a14 — 有呼吸的深邃。
    """
    pixels = img.load()
    w, h = img.size
    dark_baseline = (10, 10, 20)  # 深空基调 #0a0a14 的近似

    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            if r <= 3 and g <= 3 and b <= 3:
                pixels[x, y] = (*dark_baseline, a)
    return img


def convert_jpg_to_png(name: str) -> bool:
    jpg_path = os.path.join(GEN_DIR, f"{name}.jpg")
    png_path = os.path.join(GEN_DIR, f"{name}.png")

    if not os.path.exists(jpg_path):
        print(f"  [跳过] {name}.jpg 不存在")
        return False

    img = Image.open(jpg_path)
    original_mode = img.mode

    # 转为 RGBA
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    w, h = img.size
    pixels = img.load()

    # 边缘 Alpha 处理: 纯黑/纯白边缘 → Alpha 0
    for y in range(h):
        for x in range(w):
            if is_edge_pixel(x, y, w, h):
                r, g, b, a = pixels[x, y]
                if should_make_transparent(r, g, b):
                    pixels[x, y] = (r, g, b, 0)

    # 暗而不黑: 消除死黑像素
    img = apply_dark_but_not_black(img)

    img.save(png_path, "PNG")
    print(f"  [完成] {name}.jpg ({original_mode} {w}x{h}) → {name}.png (RGBA)")
    return True


def cleanup_old_imports() -> int:
    """删除旧的 .jpg.import 文件（已有对应的 .png.import）"""
    deleted = 0
    for name in FILES:
        old_import = os.path.join(GEN_DIR, f"{name}.jpg.import")
        if os.path.exists(old_import):
            os.remove(old_import)
            deleted += 1
            print(f"  [清理] 删除旧导入文件: {name}.jpg.import")
    return deleted


def cleanup_dead_resources() -> int:
    """P0-清理: 删除4个死资源文件及其.import文件"""
    dead = [
        "map_overview.jpg",
        "school_playground.png",
        "school_corridor.png",
        "school_classroom.png",
    ]
    deleted = 0
    for fname in dead:
        fpath = os.path.join(GEN_DIR, fname)
        ipath = os.path.join(GEN_DIR, fname + ".import")
        for p in [fpath, ipath]:
            if os.path.exists(p):
                os.remove(p)
                deleted += 1
                print(f"  [死资源] 删除: {os.path.basename(p)}")
    return deleted


def main():
    print("=" * 60)
    print("  Starforge 资产转换 — JPG → PNG (杨奇监修)")
    print("  暗而不黑 · 边缘Alpha · RGBA8")
    print("=" * 60)

    # 检查 Pillow
    try:
        from PIL import Image
    except ImportError:
        print("\n[错误] 需要安装 Pillow: pip install pillow")
        sys.exit(1)

    # Phase 1: JPG → PNG 转换
    print("\n[Phase 1] JPG → PNG 转换")
    print("-" * 40)
    success = 0
    for name in FILES:
        if convert_jpg_to_png(name):
            success += 1
    print(f"\n  转换完成: {success}/{len(FILES)}")

    # Phase 2: 清理旧 .jpg.import 文件
    print("\n[Phase 2] 清理旧 .jpg.import 文件")
    print("-" * 40)
    n = cleanup_old_imports()
    print(f"\n  删除旧导入文件: {n} 个")

    # Phase 3: 清理死资源
    print("\n[Phase 3] 清理死资源")
    print("-" * 40)
    m = cleanup_dead_resources()
    print(f"\n  删除死资源: {m} 个")

    print("\n" + "=" * 60)
    print("  全部完成。请在 Godot 编辑器中重新导入项目。")
    print("=" * 60)


if __name__ == "__main__":
    main()
