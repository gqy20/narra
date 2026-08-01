from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TARGET = Path(
    r"C:\Users\gqy17\.codex\generated_images\019fbdbf-1661-7d20-a981-2df4a66194b6\exec-44fbafa3-3edb-417c-821d-feaf37ed98a4.png"
)
OVERVIEW = ROOT / "artifacts" / "screenshots" / "ui-overview-2048x1152.png"
FOCUS = ROOT / "artifacts" / "screenshots" / "ui-actor-focus-2048x1152.png"
OUTPUT = ROOT / "artifacts" / "screenshots" / "ui-design-qa-comparison.png"


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    return copy


def main() -> None:
    width = 2048
    target = fit(Image.open(TARGET).convert("RGB"), (width, 1152))
    overview = fit(Image.open(OVERVIEW).convert("RGB"), (width // 2, 640))
    focus = fit(Image.open(FOCUS).convert("RGB"), (width // 2, 640))
    label_height = 48
    canvas = Image.new("RGB", (width, target.height + label_height + 640), "#070b08")
    canvas.paste(target, ((width - target.width) // 2, 0))
    y = target.height + label_height
    canvas.paste(overview, ((width // 2 - overview.width) // 2, y))
    canvas.paste(focus, (width // 2 + (width // 2 - focus.width) // 2, y))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=22)
    draw.text((24, target.height + 12), "IMPLEMENTATION: COMPACT OVERVIEW", fill="#d7b45a", font=font)
    draw.text((width // 2 + 24, target.height + 12), "IMPLEMENTATION: ACTOR FOCUS", fill="#d7b45a", font=font)
    draw.line((width // 2, target.height, width // 2, canvas.height), fill="#3a3321", width=2)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, optimize=True)
    print(OUTPUT)


if __name__ == "__main__":
    main()
