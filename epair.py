import os
import re
import sys
import unicodedata

# ---------- CONFIG ----------
BASE_OUTPUT_DIR = "pages"
AUTO_CREATE_PAGES = True
# ----------------------------

def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def make_paths(title: str, current_file: str):
    slug = slugify(title)
    filename = f"{slug}.html"

    # place pages folder next to the input file
    base_dir = os.path.dirname(current_file)
    output_dir = os.path.join(base_dir, BASE_OUTPUT_DIR)

    filepath = os.path.join(output_dir, filename)

    # relative link from current file → pages/
    href = os.path.relpath(filepath, start=base_dir).replace("\\", "/")

    return filepath, href


def generate_page(title: str, desc: str, filepath: str):
    if os.path.exists(filepath):
        return

    os.makedirs(os.path.dirname(filepath), exist_ok=True)

    html = f"""<!DOCTYPE html>
<html lang="en-US">
<head>
  <meta charset="UTF-8">
  <title>{title}</title>
  <link rel="stylesheet" href="https://www.w3schools.com/w3css/5/w3.css">
</head>
<body class="w3-container">
  <h1>{title}</h1>
  <p>{desc}</p>

  <p>Content not written yet.</p>

  <a href="../index.html" class="w3-button w3-teal">Back</a>
</body>
</html>
"""

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html)


def patch_html(file_path: str):
    with open(file_path, "r", encoding="utf-8") as f:
        html = f.read()

    pattern = re.compile(
        r'(<li class="w3-padding-16">.*?'
        r'<span class="w3-large">(.*?)</span><br>\s*'
        r'<span>(.*?)</span>.*?'
        r'<a class="w3-button.*?>Read More</a>)',
        re.DOTALL
    )

    def replace_block(match):
        full = match.group(1)
        title = match.group(2).strip()
        desc = match.group(3).strip()

        filepath, href = make_paths(title, file_path)

        if AUTO_CREATE_PAGES:
            generate_page(title, desc, filepath)

        new_link = f'<a href="{href}" class="w3-button w3-small w3-margin-top w3-teal">Read More</a>'

        updated = re.sub(
            r'<a class="w3-button.*?>Read More</a>',
            new_link,
            full
        )

        return updated

    new_html = pattern.sub(replace_block, html)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_html)

    print(f"[OK] Patched: {file_path}")


# ---------- ENTRY POINT ----------
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 patcher.py <file1.html> [file2.html ...]")
        sys.exit(1)

    for file in sys.argv[1:]:
        if not os.path.exists(file):
            print(f"[SKIP] Not found: {file}")
            continue

        patch_html(file)