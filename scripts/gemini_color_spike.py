#!/usr/bin/env python3
"""
Spike: Gemini Flash 3 photo color analysis quality test.

Validates whether Gemini can reliably analyze a photo and return
EditRecipe-compatible color grading parameters before we build
GeminiColorService.swift and the backend endpoint.

Usage:
    python3 scripts/gemini_color_spike.py <photo> [options]

Options:
    --mode    auto | mood | reference  (default: auto)
    --mood    cinematic | airy | moody | warm_golden | cool_urban | bw_dramatic | natural_vibrant
    --ref     Path to reference photo (reference mode only)
    --key     Gemini API key (or set GEMINI_API_KEY env var)

Requirements:
    pip install google-generativeai Pillow

Exit codes:
    0  All assertions passed
    1  JSON parse error or missing key
    2  Value out of expected range
    3  API/auth error
"""

import sys
import json
import base64
import argparse
import os
from io import BytesIO

try:
    from PIL import Image
    from google import genai
    from google.genai import types
except ImportError:
    print("ERROR: Missing dependencies. Run: pip install google-genai Pillow")
    sys.exit(3)


# ---------------------------------------------------------------------------
# EditRecipe schema — mirrors rawctl's EditRecipe.swift parameter ranges
# ---------------------------------------------------------------------------

RECIPE_SCHEMA = """\
Return ONLY a valid JSON object (no markdown, no explanation).
Use null for any parameter you don't want to change.

{
  "exposure":    float (-5.0 to +5.0 stops, 0 = no change),
  "contrast":    float (-100 to +100, 0 = no change),
  "highlights":  float (-100 to +100),
  "shadows":     float (-100 to +100),
  "whites":      float (-100 to +100),
  "blacks":      float (-100 to +100),
  "vibrance":    float (-100 to +100),
  "saturation":  float (-100 to +100),
  "temperature": float (offset in Kelvin: -200 warm to +200 cool, 0 = no change),
  "tint":        float (-50 to +50, 0 = no change),
  "clarity":     float (-100 to +100),
  "dehaze":      float (-100 to +100),
  "analysis":    string (brief description of photo content and what you changed),
  "detectedMood": string (one-word mood label)
}"""

MOOD_PROMPTS = {
    "cinematic":       "rich, de-saturated mids, lifted shadows, teal-orange colour grade",
    "airy":            "bright, soft, high-key, pastel tones, lifted blacks",
    "moody":           "dark, low-key, crushed shadows, desaturated, cool midtones",
    "warm_golden":     "golden hour warmth, lifted highlights, rich amber tones",
    "cool_urban":      "cool blue-grey tones, clean contrast, slightly faded",
    "bw_dramatic":     "high-contrast black and white, deep blacks, bright highlights",
    "natural_vibrant": "natural but punchy, boosted clarity and vibrance, clean whites",
}

EXPECTED_RANGES = {
    "exposure":    (-5.0,  5.0),
    "contrast":    (-100, 100),
    "highlights":  (-100, 100),
    "shadows":     (-100, 100),
    "whites":      (-100, 100),
    "blacks":      (-100, 100),
    "vibrance":    (-100, 100),
    "saturation":  (-100, 100),
    "temperature": (-200, 200),
    "tint":        (-50,   50),
    "clarity":     (-100, 100),
    "dehaze":      (-100, 100),
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def encode_image(path: str, max_px: int = 1024) -> str:
    """Resize to max_px long-edge and encode as base64 JPEG."""
    img = Image.open(path).convert("RGB")
    img.thumbnail((max_px, max_px), Image.LANCZOS)
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return base64.b64encode(buf.getvalue()).decode()


def build_prompt(mode: str, mood=None):
    # type: (str, str) -> str
    if mode == "auto":
        return (
            "You are a professional photo colour grading assistant.\n"
            "Analyse this photo and suggest optimal non-destructive adjustments.\n"
            "Consider: exposure balance, white balance, contrast, and aesthetic appeal.\n\n"
            + RECIPE_SCHEMA
        )
    elif mode == "mood":
        style = MOOD_PROMPTS.get(mood, mood)
        return (
            f"You are a professional photo colour grading assistant.\n"
            f'Apply a "{mood}" mood to this photo: {style}.\n'
            f"Adjust the colour grading to match that aesthetic while respecting the photo content.\n\n"
            + RECIPE_SCHEMA
        )
    elif mode == "reference":
        return (
            "You are a professional photo colour grading assistant.\n"
            "The FIRST image is the TARGET photo to grade.\n"
            "The SECOND image is the REFERENCE photo with the desired colour style.\n"
            "Analyse the reference photo's colour grading and suggest parameters to make "
            "the target look visually similar.\n\n"
            + RECIPE_SCHEMA
        )
    raise ValueError(f"Unknown mode: {mode}")


def validate_result(result: dict) -> list[str]:
    """Return list of validation errors (empty = pass)."""
    errors = []
    for field, (lo, hi) in EXPECTED_RANGES.items():
        val = result.get(field)
        if val is None:
            continue  # null is allowed
        if not isinstance(val, (int, float)):
            errors.append(f"  {field}: expected float, got {type(val).__name__} ({val!r})")
            continue
        if not (lo <= val <= hi):
            errors.append(f"  {field}: {val} out of range [{lo}, {hi}]")
    if "analysis" not in result or not result["analysis"]:
        errors.append("  missing or empty 'analysis' field")
    if "detectedMood" not in result or not result["detectedMood"]:
        errors.append("  missing or empty 'detectedMood' field")
    return errors


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run(args) -> int:
    api_key = args.key or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: Provide --key or set GEMINI_API_KEY environment variable.")
        return 3

    client = genai.Client(api_key=api_key)

    print("\n" + "=" * 60)
    print("  Gemini Flash 3 Colour Analysis Spike")
    print("=" * 60)
    print("  Photo : {}".format(args.photo))
    print("  Mode  : {}".format(args.mode + (" ({})".format(args.mood) if args.mode == "mood" else "")))
    if args.mode == "reference":
        print("  Ref   : {}".format(args.ref))
    print()

    # Build content parts (new google.genai SDK format)
    img_bytes = base64.b64decode(encode_image(args.photo))
    contents = [
        types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"),
    ]
    if args.mode == "reference":
        if not args.ref:
            print("ERROR: --ref required for reference mode.")
            return 3
        ref_bytes = base64.b64decode(encode_image(args.ref))
        contents.append(types.Part.from_bytes(data=ref_bytes, mime_type="image/jpeg"))
    contents.append(build_prompt(args.mode, args.mood))

    # Call Gemini
    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=contents,
            config=types.GenerateContentConfig(
                response_mime_type="application/json"
            ),
        )
    except Exception as e:
        print("API ERROR: {}".format(e))
        return 3

    raw = response.text.strip()

    # Parse JSON
    try:
        result = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"JSON PARSE ERROR: {e}")
        print(f"Raw response:\n{raw}")
        return 1

    # Print analysis
    print(f"  Analysis   : {result.get('analysis', '(none)')}")
    print(f"  Mood       : {result.get('detectedMood', '(none)')}")
    print()
    print("  Adjustments (non-null, non-zero):")
    has_adj = False
    for key, val in result.items():
        if key in ("analysis", "detectedMood") or val is None or val == 0:
            continue
        print(f"    {key:15s}: {val:+.1f}" if isinstance(val, float) else f"    {key:15s}: {val}")
        has_adj = True
    if not has_adj:
        print("    (no adjustments suggested)")

    # Validate ranges
    print()
    errors = validate_result(result)
    if errors:
        print("VALIDATION FAILED:")
        for e in errors:
            print(e)
        return 2

    print("✓ All validations passed — values within expected EditRecipe ranges.")
    print()
    print("  Raw JSON:")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Spike test: Gemini Flash 3 photo colour analysis"
    )
    parser.add_argument("photo", help="Path to photo to analyse")
    parser.add_argument(
        "--mode",
        choices=["auto", "mood", "reference"],
        default="auto",
        help="Analysis mode (default: auto)",
    )
    parser.add_argument(
        "--mood",
        choices=list(MOOD_PROMPTS.keys()),
        default="cinematic",
        help="Mood preset (mood mode only)",
    )
    parser.add_argument(
        "--ref",
        metavar="PATH",
        help="Reference photo path (reference mode only)",
    )
    parser.add_argument(
        "--key",
        metavar="API_KEY",
        help="Gemini API key (or set GEMINI_API_KEY env var)",
    )
    args = parser.parse_args()
    sys.exit(run(args))
