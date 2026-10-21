"""Onboarding artwork (decision 100): the guide-beam chevron. Writes an editable SVG and a transparent PNG into
assets/ui/onboarding/{svg,png}. The chevron is white so Beam.Color tints it. It points UP: a Beam lays the image's
vertical axis along its length with the top toward Attachment1 (the pad), and the horizontal axis across its width.

    python3 tools/ui/onboarding_art.py

Rendering reuses the headless-Chrome helper in daily_rewards_art.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from daily_rewards_art import render  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "onboarding")

# 128x128 tile: one fat rounded "^" chevron with a soft glow, lots of air so neighbouring tiles read as separate arrows.
CHEVRON = """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128">
  <defs><filter id="g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5"/></filter></defs>
  <path d="M22 86 L64 44 L106 86" fill="none" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="30"
        stroke-linecap="round" stroke-linejoin="round" filter="url(#g)"/>
  <path d="M22 86 L64 44 L106 86" fill="none" stroke="#FFFFFF" stroke-width="20"
        stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""

A = {"guide_chevron": CHEVRON}

if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "png"), exist_ok=True)
    for name, svg in A.items():
        open(os.path.join(OUT, "svg", name + ".svg"), "w").write(svg)
    for name, data in render(A).items():
        open(os.path.join(OUT, "png", name + ".png"), "wb").write(data)
        print(name, "written")
