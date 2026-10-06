#!/usr/bin/env python3
"""Build a self-contained comparison gallery from the color stress fixtures.

Run after `zig build`. Optional arguments: output HTML path, renderer path.
"""

import html
from pathlib import Path
import re
import subprocess
import sys

repo = Path(__file__).resolve().parent.parent
output = Path(sys.argv[1]) if len(sys.argv) > 1 else repo / "zig-out/color-gallery.html"
renderer = Path(sys.argv[2]) if len(sys.argv) > 2 else repo / "zig-out/bin/pikchresque"

header = """<!doctype html>
<html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pikchresque · color study</title>
<style>
* { box-sizing: border-box }
body { margin: 0; background: #e9e7e2; color: #252728; font: 15px system-ui }
header { padding: 24px 32px; background: #f8f7f3; border-bottom: 1px solid #ccc }
h1 { margin: 0 0 8px; font-size: 26px; font-weight: 600 }
p { margin: 6px 0; line-height: 1.5 }
nav { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 18px; align-items: center }
button, select { font: inherit; padding: 6px 12px; cursor: pointer }
main { padding: 12px 24px 36px; max-width: 1800px; margin: auto }
h2 { text-transform: capitalize; margin-bottom: 10px }
.grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px }
.panel { border-radius: 8px; overflow: hidden; border: 1px solid #bbb }
h3 { font-size: 13px; margin: 0; padding: 10px 14px; background: #f8f7f3; color: #333 }
.canvas { padding: 20px 12px; display: grid; align-items: center; height: calc(100% - 36px) }
.canvas[data-theme="light"] { background: white; color: black }
.canvas[data-theme="dark"] { background: var(--dark-bg, #15171a); color: white }
.canvas[data-theme="light"] svg { color-scheme: light !important }
.canvas[data-theme="dark"] svg { color-scheme: dark !important }
svg { width: 100%; height: auto; display: block }
details { margin-top: 10px }
summary { cursor: pointer }
pre { padding: 16px; background: #f8f7f3; overflow: auto; font-size: 12px }
@media(max-width: 900px) { .grid { grid-template-columns: 1fr } }
</style>
<header><h1>Pikchresque · color study</h1>
<p>Same source, original light colors, and two dark-mode conversions. All panels use responsive SVG color CSS.</p>
<p>Swatch tiles show a fill, an arrow, a dot, colored text, and a box with matching fill and stroke.</p>
<nav><button onclick="theme('compare')">Compare</button>
<button onclick="theme('light')">All light</button>
<button onclick="theme('dark')">All dark</button>
<label>Dark canvas <select onchange="document.documentElement.style.setProperty('--dark-bg',this.value)">
<option value="#15171a">Charcoal</option><option value="#000000">Black</option>
<option value="#282828">Warm gray</option></select></label></nav></header><main>
"""

sections = [header]
fixtures = [repo / f"piks/colors/{name}.pikchr" for name in
            ("saturated", "roles", "pastels", "deep", "neutral")]
fixtures.append(repo / "piks/tests/colortest1.pikchr")
for fixture in fixtures:
    sections.append(f"<section><h2>{html.escape(fixture.stem)}</h2><div class=\"grid\">")
    for variant, label, theme, flags in [
        ("light", "Original · light", "light", []),
        ("oklch", "OKLCH · default", "dark", []),
        ("classic", "RGB · classic", "dark", ["--classic-colorspace"]),
    ]:
        svg = subprocess.run(
            [str(renderer), "--svg-only", *flags, str(fixture)],
            check=True, capture_output=True, text=True,
        ).stdout
        # Each copy needs its own SVG id and matching CSS / accessibility references.
        svg = re.sub(r"-[0-9a-f]{10}\b", lambda m: m[0] + "-" + variant, svg)
        sections.append(f'<div class="panel" data-label="{label}" data-model="'
                        f'{"RGB · classic" if variant == "classic" else "OKLCH"}">'
                        f'<h3>{label}</h3><div class="canvas" '
                        f'data-initial="{theme}" data-theme="{theme}">{svg}</div></div>')
    sections.append('</div><details><summary>' + html.escape(str(fixture.relative_to(repo))) +
                    '</summary><pre>' + html.escape(fixture.read_text()) + '</pre></details></section>')

sections.append("""</main><script>
function theme(mode) {
  document.querySelectorAll('.canvas').forEach(panel => {
    panel.dataset.theme = mode === 'compare' ? panel.dataset.initial : mode;
    panel.parentElement.querySelector('h3').textContent = mode === 'compare'
      ? panel.parentElement.dataset.label : panel.parentElement.dataset.model + ' · ' + mode;
  });
}
</script></html>""")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("\n".join(sections))
print(output)
