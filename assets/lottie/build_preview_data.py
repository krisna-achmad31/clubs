"""Bungkus JSON Lottie di animals/ jadi file .js supaya animals_preview.html
bisa dibuka dobel-klik (file://) tanpa server. Jalankan ulang setelah
generate_animal_lottie.py."""
import json
from pathlib import Path

HERE = Path(__file__).parent
SRC = HERE / "animals"
OUT = HERE / "animals_js"
OUT.mkdir(exist_ok=True)

groups = {}
for f in sorted(SRC.glob("*.json")):
    animal = "_".join(f.stem.split("_")[:2])
    groups.setdefault(animal, {})[f.stem] = json.loads(f.read_text(encoding="utf-8"))

for animal, anims in groups.items():
    body = json.dumps(anims, separators=(",", ":"))
    (OUT / f"{animal}.js").write_text(
        f"window.KLUBBY_ANIM=Object.assign(window.KLUBBY_ANIM||{{}},{body});\n", encoding="utf-8")
print(f"{len(groups)} file .js ditulis ke {OUT}")
