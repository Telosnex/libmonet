#!/usr/bin/env python3
"""Generate a Dart table of raster-measured Google Fonts visual heights.

This intentionally uses rasterization offline so runtime theme construction can
use a plain synchronous lookup. The runtime scale uses a trimmed mean of actual
rendered phrase heights from a small body/UI corpus.
"""

from __future__ import annotations

import argparse
import hashlib
import math
import os
import re
import statistics
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from urllib.request import urlopen

from PIL import Image, ImageDraw, ImageFont


_VISUAL_HEIGHT_PHRASES = [
    "Clear Prompt",
    "Goal",
    "Safety",
    "Sign in",
    "Start",
]

FontMetricRow = tuple[str, str, int, float, float, float, float, float, float]


@dataclass(frozen=True)
class GoogleFontVariant:
    family: str
    weight: int
    hash: str
    expected_length: int


@dataclass(frozen=True)
class MeasurementResult:
    family: str
    row: FontMetricRow | None
    skipped_uncached: bool
    error: str | None
    elapsed_seconds: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default="lib/fonts/font_height_equalizer.g.dart",
        help="Dart file to write.",
    )
    parser.add_argument(
        "--cache-dir",
        default="test/output/font_metrics/google_fonts_ttf_cache",
        help="TTF cache directory.",
    )
    parser.add_argument(
        "--preferred-weight",
        type=int,
        default=500,
        help="Preferred normal style weight. Falls back to 400, then first normal variant.",
    )
    parser.add_argument(
        "--font-size",
        type=int,
        default=512,
        help="Raster font size used for measurement.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=max(1, min(12, os.cpu_count() or 1)),
        help="Parallel font measurement workers.",
    )
    parser.add_argument(
        "--cached-only",
        action="store_true",
        help="Skip fonts whose TTF is not already present in --cache-dir.",
    )
    parser.add_argument(
        "--reference-family",
        default="Roboto",
        help="Family whose visual-height metric is the 1.0 equalization target.",
    )
    return parser.parse_args()


def parse_version(path: Path) -> tuple[int, ...]:
    match = re.search(r"google_fonts-([0-9.]+)", path.name)
    if not match:
        return (0,)
    return tuple(int(part) for part in match.group(1).split("."))


def locked_google_fonts_version() -> str | None:
    lockfile = Path("pubspec.lock")
    if not lockfile.exists():
        return None
    text = lockfile.read_text()
    match = re.search(
        r"google_fonts:\n(?:\s+[^\n]+\n)*?\s+version: \"?([^\"\n]+)\"?",
        text,
    )
    return match.group(1) if match else None


def find_google_fonts_package() -> Path:
    locked_version = locked_google_fonts_version()
    if locked_version is not None:
        locked_path = Path.home() / f".pub-cache/hosted/pub.dev/google_fonts-{locked_version}"
        if locked_path.exists():
            return locked_path

    candidates = sorted(
        Path.home().glob(".pub-cache/hosted/pub.dev/google_fonts-*"),
        key=parse_version,
    )
    if not candidates:
        raise RuntimeError("Could not find google_fonts in ~/.pub-cache.")
    return candidates[-1]


def google_fonts_index(
    package_dir: Path,
) -> tuple[dict[str, str], dict[str, str], dict[str, str]]:
    all_parts = package_dir / "lib/src/google_fonts_all_parts.dart"
    if not all_parts.exists():
        all_parts = package_dir / "lib/src/google_fonts_all_parts.g.dart"
    parts_dir = package_dir / "lib/src/google_fonts_parts"
    all_text = all_parts.read_text()

    family_to_method: dict[str, str] = {}
    for family, method in re.findall(
        r"'([^']+)':\s+Part[A-Z]\.([A-Za-z0-9_]+),",
        all_text,
    ):
        family_to_method.setdefault(family, method)

    method_to_file: dict[str, str] = {}
    file_texts: dict[str, str] = {}
    part_files = list(parts_dir.glob("part_*.dart")) + list(parts_dir.glob("part_*.g.dart"))
    for path in part_files:
        text = path.read_text()
        file_texts[path.name] = text
        for match in re.finditer(r"static TextStyle ([A-Za-z0-9_]+)\(", text):
            method_to_file[match.group(1)] = path.name
    return family_to_method, method_to_file, file_texts


def variants_for_family(
    family: str,
    index: tuple[dict[str, str], dict[str, str], dict[str, str]],
) -> list[GoogleFontVariant]:
    family_to_method, method_to_file, file_texts = index
    method = family_to_method[family]
    file_name = method_to_file[method]
    text = file_texts[file_name]
    start = text.find(f"static TextStyle {method}(")
    end = text.find("return googleFontsTextStyle", start)
    block = text[start:end]
    variants: list[GoogleFontVariant] = []
    for match in re.finditer(
        r"fontWeight: FontWeight\.w(\d+),\s*"
        r"fontStyle: FontStyle\.normal,\s*"
        r"\): GoogleFontsFile\(\s*'([0-9a-f]+)',\s*(\d+),",
        block,
        re.S,
    ):
        variants.append(
            GoogleFontVariant(
                family=family,
                weight=int(match.group(1)),
                hash=match.group(2),
                expected_length=int(match.group(3)),
            )
        )
    return variants


def choose_variant(variants: list[GoogleFontVariant], preferred_weight: int) -> GoogleFontVariant:
    preferred = next((variant for variant in variants if variant.weight == preferred_weight), None)
    regular = next((variant for variant in variants if variant.weight == 400), None)
    return preferred or regular or variants[0]


def download_ttf(
    variant: GoogleFontVariant,
    cache_dir: Path,
    cached_only: bool = False,
) -> Path | None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{variant.hash}.ttf"
    if not path.exists() or path.stat().st_size != variant.expected_length:
        if cached_only:
            return None
        with urlopen(f"https://fonts.gstatic.com/s/a/{variant.hash}.ttf", timeout=30) as response:
            path.write_bytes(response.read())
    data = path.read_bytes()
    actual_hash = hashlib.sha256(data).hexdigest()
    if actual_hash != variant.hash:
        raise RuntimeError(f"Hash mismatch for {variant.family}: expected {variant.hash}, got {actual_hash}")
    return path


class RasterMeasurer:
    def __init__(self, path: Path, font_size: int) -> None:
        self.font_size = font_size
        self.font = ImageFont.truetype(str(path), font_size)
        self.ascent, self.descent = self.font.getmetrics()
        self.pad = font_size // 2
        self.probe = ImageDraw.Draw(Image.new("L", (1, 1)))
        self.image_height = self.ascent + self.descent + self.pad * 2
        self.baseline = self.pad + self.ascent

    def text_bounds_em(self, text: str) -> tuple[float, float] | None:
        width = max(
            self.font_size * 2,
            int(self.probe.textlength(text, font=self.font)) + self.pad * 2,
        )
        image = Image.new("L", (width, self.image_height), 0)
        draw = ImageDraw.Draw(image)
        draw.text((self.pad, self.baseline), text, font=self.font, fill=255, anchor="ls")
        bbox = image.getbbox()
        if bbox is None:
            return None
        _, top, _, bottom = bbox
        return top / self.font_size, bottom / self.font_size

    def text_height_em(self, text: str) -> float | None:
        bounds = self.text_bounds_em(text)
        if bounds is None:
            return None
        top, bottom = bounds
        return bottom - top


def raster_text_height_em(path: Path, text: str, font_size: int) -> float | None:
    return RasterMeasurer(path, font_size).text_height_em(text)


def raster_char_height_em(path: Path, char: str, font_size: int) -> float | None:
    return raster_text_height_em(path, char, font_size)


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        raise ValueError("percentile requires at least one value")
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    low = math.floor(position)
    high = math.ceil(position)
    if low == high:
        return ordered[low]
    return ordered[low] * (high - position) + ordered[high] * (position - low)


def trimmed_mean(values: list[float], trim_fraction: float = 0.15) -> float:
    if not values:
        raise ValueError("trimmed_mean requires at least one value")
    ordered = sorted(values)
    trim = int(len(ordered) * trim_fraction)
    trimmed = ordered[trim : len(ordered) - trim]
    return sum(trimmed or ordered) / len(trimmed or ordered)


def normalize_family(family: str) -> str:
    if "/" in family:
        family = family.rsplit("/", 1)[1]
    return re.sub(r"[^A-Za-z0-9]", "", family).lower()


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def measure_variant(
    variant: GoogleFontVariant,
    cache_dir: str,
    cached_only: bool,
    font_size: int,
) -> MeasurementResult:
    started = time.monotonic()
    try:
        path = download_ttf(variant, Path(cache_dir), cached_only=cached_only)
        if path is None:
            return MeasurementResult(variant.family, None, True, None, time.monotonic() - started)

        measurer = RasterMeasurer(path, font_size)
        letter_bounds = {
            char: bounds
            for char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
            if (bounds := measurer.text_bounds_em(char)) is not None
        }
        x_bounds = letter_bounds.get("x")
        cap_bounds = letter_bounds.get("H")
        x_height = None if x_bounds is None else x_bounds[1] - x_bounds[0]
        cap_height = None if cap_bounds is None else cap_bounds[1] - cap_bounds[0]
        lowercase_heights = [
            bottom - top
            for char, (top, bottom) in letter_bounds.items()
            if char.islower()
        ]
        uppercase_heights = [
            bottom - top
            for char, (top, bottom) in letter_bounds.items()
            if char.isupper()
        ]
        phrase_heights = [
            height
            for height in (measurer.text_height_em(phrase) for phrase in _VISUAL_HEIGHT_PHRASES)
            if height is not None
        ]
        if (
            x_height is None
            or cap_height is None
            or not lowercase_heights
            or not uppercase_heights
            or not phrase_heights
        ):
            return MeasurementResult(
                variant.family,
                None,
                False,
                "missing glyph or phrase measurements",
                time.monotonic() - started,
            )

        lowercase_p60_height = percentile(lowercase_heights, 0.60)
        uppercase_median_height = statistics.median(uppercase_heights)
        phrase_trimmed_mean_height = trimmed_mean(phrase_heights)
        visual_height = phrase_trimmed_mean_height
        row: FontMetricRow = (
            normalize_family(variant.family),
            variant.family,
            variant.weight,
            x_height,
            cap_height,
            lowercase_p60_height,
            uppercase_median_height,
            phrase_trimmed_mean_height,
            visual_height,
        )
        return MeasurementResult(variant.family, row, False, None, time.monotonic() - started)
    except Exception as error:
        return MeasurementResult(variant.family, None, False, str(error), time.monotonic() - started)


def write_dart(
    output: Path,
    package_dir: Path,
    reference_family: str,
    reference_x_height: float,
    reference_cap_height: float,
    reference_lowercase_p60_height: float,
    reference_uppercase_median_height: float,
    reference_phrase_height: float,
    reference_visual_height: float,
    rows: list[FontMetricRow],
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Generated by lib/fonts/generate_font_height_equalizer.py.",
        f"// Source package: {package_dir.name}.",
        "",
        "const kReferenceVisualHeightFamily = " + dart_string(reference_family) + ";",
        f"const kReferenceRasterXHeightEm = {reference_x_height:.6f};",
        f"const kReferenceRasterCapHeightEm = {reference_cap_height:.6f};",
        f"const kReferenceRasterLowercaseP60HeightEm = {reference_lowercase_p60_height:.6f};",
        f"const kReferenceRasterUppercaseMedianHeightEm = {reference_uppercase_median_height:.6f};",
        f"const kReferenceRasterPhraseHeightEm = {reference_phrase_height:.6f};",
        f"const kReferenceRasterVisualHeightEm = {reference_visual_height:.6f};",
        "",
        "const kRasterXHeightEmByFontFamily = <String, double>{",
    ]
    for normalized, family, weight, x_height, _, _, _, _, _ in rows:
        lines.append(f"  {dart_string(normalized)}: {x_height:.6f}, // {family} w{weight}")
    lines.extend(["};", "", "const kRasterCapHeightEmByFontFamily = <String, double>{"])
    for normalized, family, weight, _, cap_height, _, _, _, _ in rows:
        lines.append(f"  {dart_string(normalized)}: {cap_height:.6f}, // {family} w{weight}")
    lines.extend(["};", "", "const kRasterLowercaseP60HeightEmByFontFamily = <String, double>{"])
    for normalized, family, weight, _, _, lowercase_p60_height, _, _, _ in rows:
        lines.append(f"  {dart_string(normalized)}: {lowercase_p60_height:.6f}, // {family} w{weight}")
    lines.extend(["};", "", "const kRasterUppercaseMedianHeightEmByFontFamily = <String, double>{"])
    for normalized, family, weight, _, _, _, uppercase_median_height, _, _ in rows:
        lines.append(f"  {dart_string(normalized)}: {uppercase_median_height:.6f}, // {family} w{weight}")
    lines.extend(["};", "", "const kRasterPhraseHeightEmByFontFamily = <String, double>{"])
    for normalized, family, weight, _, _, _, _, phrase_height, _ in rows:
        lines.append(f"  {dart_string(normalized)}: {phrase_height:.6f}, // {family} w{weight}")
    lines.extend(["};", "", "const kRasterVisualHeightEmByFontFamily = <String, double>{"])
    for normalized, family, weight, _, _, _, _, _, visual_height in rows:
        lines.append(f"  {dart_string(normalized)}: {visual_height:.6f}, // {family} w{weight}")
    lines.extend(
        [
            "};",
            "",
            "String normalizeFontFamilyForFontMetrics(String fontFamily) {",
            "  final packageSeparator = fontFamily.lastIndexOf('/');",
            "  final unprefixed = packageSeparator < 0",
            "      ? fontFamily",
            "      : fontFamily.substring(packageSeparator + 1);",
            "  final withoutGoogleFontsVariant = unprefixed.replaceFirst(",
            "    RegExp(r'_(regular|italic|[1-9]00(?:italic)?)$'),",
            "    '',",
            "  );",
            "  return withoutGoogleFontsVariant",
            "      .replaceAll(RegExp('[^A-Za-z0-9]'), '')",
            "      .toLowerCase();",
            "}",
            "",
            "/// Raw raster x-height for a font family, when known.",
            "///",
            "/// Useful for matching monospace/code text to surrounding prose; that",
            "/// use case should generally prefer x-height over role visual-height.",
            "double? rasterXHeightEmForFontFamily(String? fontFamily) {",
            "  if (fontFamily == null) return null;",
            "  return kRasterXHeightEmByFontFamily[normalizeFontFamilyForFontMetrics(fontFamily)];",
            "}",
            "",
            "double? rasterCapHeightEmForFontFamily(String? fontFamily) {",
            "  if (fontFamily == null) return null;",
            "  return kRasterCapHeightEmByFontFamily[normalizeFontFamilyForFontMetrics(fontFamily)];",
            "}",
            "",
            "double? rasterVisualHeightEmForFontFamily(String? fontFamily) {",
            "  if (fontFamily == null) return null;",
            "  return kRasterVisualHeightEmByFontFamily[normalizeFontFamilyForFontMetrics(fontFamily)];",
            "}",
            "",
            "/// Scale for normal text-theme roles relative to the reference font.",
            "///",
            "/// This is phrase-height based and intended for display/headline/body/label",
            "/// role sizing, not for matching monospace code to prose.",
            "double visualHeightScaleForFontFamily(String? fontFamily) {",
            "  final visualHeightEm = rasterVisualHeightEmForFontFamily(fontFamily);",
            "  if (visualHeightEm == null || visualHeightEm <= 0) return 1.0;",
            "  return kReferenceRasterVisualHeightEm / visualHeightEm;",
            "}",
        ]
    )
    output.write_text("\n".join(lines) + "\n")


def main() -> None:
    args = parse_args()
    package_dir = find_google_fonts_package()
    index = google_fonts_index(package_dir)
    family_to_method = index[0]
    cache_dir = Path(args.cache_dir)

    tasks: list[GoogleFontVariant] = []
    for family in sorted(family_to_method):
        variants = variants_for_family(family, index)
        if variants:
            tasks.append(choose_variant(variants, args.preferred_weight))

    started = time.monotonic()
    rows: list[FontMetricRow] = []
    skipped_uncached = 0
    failed = 0
    total = len(tasks)
    print(f"measuring {total} fonts with {args.workers} workers", flush=True)

    if args.workers <= 1:
        results = [
            measure_variant(variant, str(cache_dir), args.cached_only, args.font_size)
            for variant in tasks
        ]
    else:
        with ProcessPoolExecutor(max_workers=args.workers) as executor:
            futures = [
                executor.submit(
                    measure_variant,
                    variant,
                    str(cache_dir),
                    args.cached_only,
                    args.font_size,
                )
                for variant in tasks
            ]
            results = []
            for completed, future in enumerate(as_completed(futures), start=1):
                result = future.result()
                results.append(result)
                if result.row is not None:
                    rows.append(result.row)
                elif result.skipped_uncached:
                    skipped_uncached += 1
                else:
                    failed += 1
                    print(f"  failed {result.family}: {result.error}", flush=True)
                if result.elapsed_seconds > 5:
                    print(f"  slow {result.family}: {result.elapsed_seconds:.1f}s", flush=True)
                if completed % 100 == 0 or completed == total:
                    elapsed = time.monotonic() - started
                    print(
                        f"  progress: {completed}/{total} measured={len(rows)} "
                        f"skipped_uncached={skipped_uncached} failed={failed} "
                        f"elapsed={elapsed:.1f}s",
                        flush=True,
                    )
    if args.workers <= 1:
        for completed, result in enumerate(results, start=1):
            if result.row is not None:
                rows.append(result.row)
            elif result.skipped_uncached:
                skipped_uncached += 1
            else:
                failed += 1
                print(f"  failed {result.family}: {result.error}", flush=True)
            if result.elapsed_seconds > 5:
                print(f"  slow {result.family}: {result.elapsed_seconds:.1f}s", flush=True)
            if completed % 100 == 0 or completed == total:
                elapsed = time.monotonic() - started
                print(
                    f"  progress: {completed}/{total} measured={len(rows)} "
                    f"skipped_uncached={skipped_uncached} failed={failed} elapsed={elapsed:.1f}s",
                    flush=True,
                )

    reference = next((row for row in rows if row[1] == args.reference_family), None)
    if reference is None:
        raise RuntimeError(f"Reference family {args.reference_family!r} was not measured.")

    rows.sort(key=lambda row: row[0])
    write_dart(
        Path(args.output),
        package_dir,
        args.reference_family,
        reference[3],
        reference[4],
        reference[5],
        reference[6],
        reference[7],
        reference[8],
        rows,
    )
    print(f"wrote {args.output} with {len(rows)} visual-height entries", flush=True)
    print(f"{args.reference_family} x-height: {reference[3]:.6f}em", flush=True)
    print(f"{args.reference_family} cap-height: {reference[4]:.6f}em", flush=True)
    print(f"{args.reference_family} lowercase-p60-height: {reference[5]:.6f}em", flush=True)
    print(f"{args.reference_family} uppercase-median-height: {reference[6]:.6f}em", flush=True)
    print(f"{args.reference_family} phrase-height: {reference[7]:.6f}em", flush=True)
    print(f"{args.reference_family} visual-height: {reference[8]:.6f}em", flush=True)


if __name__ == "__main__":
    main()
