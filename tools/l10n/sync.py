#!/usr/bin/env python3
"""Generates the string catalogs from docs/ios/copy.md.

    python3 tools/l10n/sync.py             writes QuickCover/Localizable.xcstrings and
                                           QuickCover/InfoPlist.xcstrings
    python3 tools/l10n/sync.py --check     exit 1 when either catalog is out of date, when a Swift
                                           source uses a copy number copy.md doesn't have, or when
                                           the project lacks the English base of the two photo
                                           prompts

The key of every string is its number in copy.md ("3.1.1", "4.5.07"), so the interface can only
say what copy.md says. In Swift that is `Text("4.4.1")`, `Button("6.1.3") {}` or
`String(localized: "5.2.1")`; the four {n} rows go through `L10n` (plural forms).

Rows with {n} become plural variations: Chinese has the one form; English is written
"one form · other form" and is split on " · ".

Seven keys don't have a row of their own; each is read off copy.md and says so in its comment:
  7.1.lead, 7.1.join, 7.1.lastJoin   the screen-reader summary (copy.md §7 rule), checked below by
                                     putting the 7.1 example back together from 4.3.1-4.3.4
  4.3.sep                            the separator of the on-screen summary (copy.md §4.3: 「 · 」;
                                     design.md §3: a no-break space either side)

Keys that aren't copy numbers (the scaffold's "Made with AirBuild") are left alone.

Keys are marked "manual" so Xcode's string extraction never marks them stale; `--check` ignores
`extractionState` because Xcode rewrites it. Python 3.9 or later, standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COPY = ROOT / "docs" / "ios" / "copy.md"
LOCALIZABLE = ROOT / "QuickCover" / "Localizable.xcstrings"
INFOPLIST = ROOT / "QuickCover" / "InfoPlist.xcstrings"
PROJECT = ROOT / "QuickCover.xcodeproj" / "project.pbxproj"
SWIFT_ROOT = ROOT / "QuickCover"

SOURCE_LANGUAGE = "en"
LANGUAGES = ("zh-Hans", "zh-Hant", "en")

# System prompts (copy.md §3.3): the row for each Info.plist key. The English value is also the
# project's base text, so a phone in a fourth language still reads a real sentence.
INFOPLIST_ROWS = {
    "NSPhotoLibraryUsageDescription": "3.3.1",
    "NSPhotoLibraryAddUsageDescription": "3.3.2",
}
INFOPLIST_SETTING = "INFOPLIST_KEY_"

# copy.md §7: how 7.1 is put together. Verified against the 7.1 example on every run.
SUMMARY_JOIN = {"zh-Hans": "、", "zh-Hant": "、", "en": ", "}
SUMMARY_LAST_JOIN = {"zh-Hans": "、", "zh-Hant": "、", "en": " and "}
SUMMARY_EXAMPLE = (2, 5, 1, 0)  # the counts in the 7.1 example row
SUMMARY_ROWS = ("4.3.1", "4.3.2", "4.3.3", "4.3.4")
SUMMARY_SEPARATOR = "\u00a0\u00b7\u00a0"

ROW = re.compile(r"^\|\s*(\d+(?:\.\d+)+)\s*\|(.*)\|\s*$")
HEADING = re.compile(r"^#{2,3}\s+(.*?)\s*$")
COPY_NUMBER = re.compile(r"^\d+(?:\.\d+)+$")
SWIFT_KEY = re.compile(r'"(\d+(?:\.\d+)+)"')
DISPLAY_NAME = re.compile(r"图标下的名字：简体「(.+?)」\s*·\s*繁体「(.+?)」\s*·\s*英文\s+(\S+)")

DERIVED_KEYS = ("4.3.sep", "7.1.lead", "7.1.join", "7.1.lastJoin")


class CopyError(Exception):
    pass


class Row:
    def __init__(self, number: str, cells: list[str], heading: str, line: int):
        self.number = number
        self.line = line
        self.heading = heading
        if len(cells) < 3 or not all(cells[:3]):
            raise CopyError(f"copy.md:{line}: row {number} needs 简体, 繁体 and 英文")
        self.values = dict(zip(LANGUAGES, cells[:3]))
        self.note = cells[3] if len(cells) > 3 and cells[3] else ""


def natural_key(key: str):
    """4.3.1 < 4.3.4 < 4.3.sep < 4.4.1: by number, then anything after the last number."""
    numbers = []
    for part in key.split("."):
        if part.isdigit():
            numbers.append(int(part))
        else:
            break
    trailing = ".".join(key.split(".")[len(numbers):])
    return (numbers, trailing, key)


def parse_copy(text: str) -> dict[str, Row]:
    rows: dict[str, Row] = {}
    heading = ""
    for number, line in enumerate(text.splitlines(), start=1):
        found = HEADING.match(line)
        if found:
            heading = found.group(1)
            continue
        found = ROW.match(line)
        if not found:
            continue
        key = found.group(1)
        cells = [cell.strip() for cell in found.group(2).split("|")]
        if key in rows:
            raise CopyError(f"copy.md:{number}: row {key} appears twice")
        rows[key] = Row(key, cells, heading, number)
    return rows


def plain(row: Row, language: str) -> str:
    value = row.values[language]
    if "{n}" in value:
        raise CopyError(f"copy.md:{row.line}: row {row.number} has {{n}} but isn't one of the "
                        f"plural rows {', '.join(SUMMARY_ROWS)}")
    if "%" in value:
        raise CopyError(f"copy.md:{row.line}: row {row.number} has a % sign; escape it before it "
                        "can go through String(format:)")
    return value


def plural_forms(row: Row, language: str) -> dict[str, str]:
    """{category: format} for one language of a {n} row."""
    value = row.values[language]
    if "{n}" not in value:
        raise CopyError(f"copy.md:{row.line}: row {row.number} should contain {{n}}")
    if language == "en":
        forms = value.split(" · ")
        if len(forms) != 2:
            raise CopyError(f"copy.md:{row.line}: row {row.number} English should be "
                            "'one form · other form'")
        forms = dict(zip(("one", "other"), forms))
    else:
        forms = {"other": value}
    for category, form in forms.items():
        if form.count("{n}") != 1:
            raise CopyError(f"copy.md:{row.line}: row {row.number} {language} {category} should "
                            "have {n} exactly once")
        forms[category] = form.replace("{n}", "%lld")
    return forms


def plural_value(row: Row, language: str, n: int) -> str:
    forms = plural_forms(row, language)
    category = "one" if language == "en" and n == 1 else "other"
    return forms[category].replace("%lld", str(n))


def string_unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def entry(comment: str, localizations: dict) -> dict:
    return {"comment": comment, "extractionState": "manual", "localizations": localizations}


def comment_for(row: Row) -> str:
    return f"copy.md §{row.heading} · {row.number}" + (f" · {row.note}" if row.note else "")


def summary_lead(row: Row, language: str) -> str:
    """「找到」/ "Found": what stands before the first count in the 7.1 example."""
    match = re.match(r"^(.*?)(?=\s+\d)", row.values[language])
    if not match or not match.group(1):
        raise CopyError(f"copy.md:{row.line}: row 7.1 {language} doesn't start with a word "
                        "before the first number")
    return match.group(1)


def verify_summary_example(rows: dict[str, Row], lead: dict[str, str]) -> None:
    """The 7.1 example must come out of 4.3.1-4.3.4, the lead and the joins, in every language."""
    for language in LANGUAGES:
        parts = [plural_value(rows[key], language, n)
                 for key, n in zip(SUMMARY_ROWS, SUMMARY_EXAMPLE) if n > 0]
        joined = (SUMMARY_JOIN[language].join(parts[:-1]) + SUMMARY_LAST_JOIN[language] + parts[-1])
        expected = lead[language] + " " + joined
        if expected != rows["7.1"].values[language]:
            raise CopyError(
                f"copy.md:{rows['7.1'].line}: 7.1 {language} isn't what §7's rule makes of 4.3.1-4.3.4:\n"
                f"  example: {rows['7.1'].values[language]}\n  composed: {expected}")


def build_localizable(rows: dict[str, Row], existing: dict) -> dict:
    strings: dict[str, dict] = {}
    for key in sorted((k for k in rows if k not in ("3.3.1", "3.3.2", "7.1")), key=natural_key):
        row = rows[key]
        if key in SUMMARY_ROWS:
            strings[key] = entry(comment_for(row), {
                language: {"variations": {"plural": {category: string_unit(form)
                                                     for category, form in plural_forms(row, language).items()}}}
                for language in LANGUAGES})
        else:
            strings[key] = entry(comment_for(row), {language: string_unit(plain(row, language))
                                                    for language in LANGUAGES})

    lead = {language: summary_lead(rows["7.1"], language) for language in LANGUAGES}
    verify_summary_example(rows, lead)

    strings["4.3.sep"] = entry(
        "Not a row. The separator between the parts of the on-screen summary (copy.md §4.3 「 · 」; "
        "design.md §3: U+00A0 · U+00A0 so it never breaks).",
        {language: string_unit(SUMMARY_SEPARATOR) for language in LANGUAGES})
    strings["7.1.lead"] = entry(
        "Not a row. The first word of the screen-reader summary: what stands before the first count "
        "in the 7.1 example (copy.md §7 rule).",
        {language: string_unit(lead[language]) for language in LANGUAGES})
    for key, table, what in (("7.1.join", SUMMARY_JOIN, "joins the parts"),
                             ("7.1.lastJoin", SUMMARY_LAST_JOIN, "goes before the last part")):
        strings[key] = entry(
            f"Not a row. What {what} of the screen-reader summary (copy.md §7 rule: 「、」, or a "
            "comma and \"and\" before the last part).",
            {language: string_unit(table[language]) for language in LANGUAGES})

    # Keys that aren't copy numbers belong to whoever wrote them; keep them as they are.
    for key, value in existing.get("strings", {}).items():
        if not COPY_NUMBER.match(key) and key not in DERIVED_KEYS:
            strings[key] = value
    return {"sourceLanguage": SOURCE_LANGUAGE, "strings": strings, "version": "1.0"}


def display_name(text: str) -> dict[str, str]:
    match = DISPLAY_NAME.search(text)
    if not match:
        raise CopyError("copy.md §1: the line 「图标下的名字：简体「…」· 繁体「…」· 英文 …」 wasn't found")
    hans, hant, en = match.groups()
    return {"zh-Hans": hans, "zh-Hant": hant, "en": en}


def build_infoplist(rows: dict[str, Row], copy_text: str, existing: dict) -> dict:
    strings: dict[str, dict] = {}
    names = display_name(copy_text)
    strings["CFBundleDisplayName"] = entry(
        "The name under the icon (copy.md §1).",
        {language: string_unit(names[language]) for language in LANGUAGES})
    for key, number in INFOPLIST_ROWS.items():
        strings[key] = entry(f"copy.md §{rows[number].heading} · {number} · the system prompt",
                             {language: string_unit(plain(rows[number], language))
                              for language in LANGUAGES})
    for key, value in existing.get("strings", {}).items():
        strings.setdefault(key, value)
    return {"sourceLanguage": SOURCE_LANGUAGE, "strings": strings, "version": "1.0"}


# MARK: - Comparing with what is on disk


def normalize(catalog) -> object:
    """The catalog without anything Xcode rewrites on its own, and with keys sorted."""
    if isinstance(catalog, dict):
        return {key: normalize(value) for key, value in sorted(catalog.items()) if key != "extractionState"}
    if isinstance(catalog, list):
        return [normalize(value) for value in catalog]
    return catalog


def differences(generated: dict, existing: dict, path: str) -> list[str]:
    out: list[str] = []
    if generated.get("sourceLanguage") != existing.get("sourceLanguage"):
        out.append(f"{path}: sourceLanguage is {existing.get('sourceLanguage')!r}, "
                   f"should be {generated.get('sourceLanguage')!r}")
    old, new = existing.get("strings", {}), generated.get("strings", {})
    for key in sorted(set(new) | set(old), key=natural_key):
        if key not in old:
            out.append(f"{path}: missing key {key}")
        elif key not in new:
            out.append(f"{path}: key {key} is not in copy.md (row removed, or a typo)")
        else:
            a, b = normalize(new[key]), normalize(old[key])
            if a != b:
                for language in LANGUAGES:
                    want = a.get("localizations", {}).get(language)
                    have = b.get("localizations", {}).get(language)
                    if want != have:
                        out.append(f"{path}: {key} {language} is {have!r}, copy.md says {want!r}")
                if normalize({k: v for k, v in a.items() if k != "localizations"}) != \
                        normalize({k: v for k, v in b.items() if k != "localizations"}):
                    out.append(f"{path}: {key} differs outside its localizations")
    return out


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise CopyError(f"{path.relative_to(ROOT)}: not valid JSON ({error})") from error


def dump(catalog: dict) -> str:
    # The way Xcode writes a catalog: two-space indent, a space either side of the colon.
    return json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n"


def swift_keys_outside_copy(rows: dict[str, Row], derived) -> list[str]:
    out = []
    known = set(rows) | set(derived)
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for key in SWIFT_KEY.findall(line):
                if key not in known:
                    out.append(f"{path.relative_to(ROOT)}:{number}: \"{key}\" isn't a row of copy.md")
    return out


def project_prompt_settings(rows: dict[str, Row]) -> list[str]:
    if not PROJECT.exists():
        return []
    text = PROJECT.read_text(encoding="utf-8")
    out = []
    for key, number in INFOPLIST_ROWS.items():
        setting = INFOPLIST_SETTING + key
        wanted = plain(rows[number], "en")
        found = re.findall(r"^\s*" + re.escape(setting) + r'\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', text, re.M)
        if not found:
            out.append(f"{PROJECT.relative_to(ROOT)}: {setting} is missing; it carries the English "
                       f"text of copy.md {number} for languages the app doesn't have")
        elif any(json.loads('"' + value + '"') != wanted for value in found):
            out.append(f"{PROJECT.relative_to(ROOT)}: {setting} should be {wanted!r} (copy.md {number})")
        elif len(found) < 2:
            out.append(f"{PROJECT.relative_to(ROOT)}: {setting} is set in {len(found)} build "
                       "configuration(s); Debug and Release both need it")
    return out


def generate(copy_text: str, localizable: dict, infoplist: dict) -> tuple[dict, dict]:
    rows = parse_copy(copy_text)
    for number in ("7.1",) + SUMMARY_ROWS + tuple(INFOPLIST_ROWS.values()):
        if number not in rows:
            raise CopyError(f"copy.md: row {number} is missing")
    return (build_localizable(rows, localizable),
            build_infoplist(rows, copy_text, infoplist))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the string catalogs from copy.md.")
    parser.add_argument("--check", action="store_true",
                        help="don't write; fail when the catalogs, the Swift sources or the project "
                             "are out of step with copy.md")
    args = parser.parse_args(argv)

    try:
        copy_text = COPY.read_text(encoding="utf-8")
        rows = parse_copy(copy_text)
        localizable = build_localizable(rows, load(LOCALIZABLE))
        infoplist = build_infoplist(rows, copy_text, load(INFOPLIST))
    except (CopyError, OSError) as error:
        print(f"sync.py: {error}", file=sys.stderr)
        return 2

    if args.check:
        problems = (differences(localizable, load(LOCALIZABLE), str(LOCALIZABLE.relative_to(ROOT)))
                    + differences(infoplist, load(INFOPLIST), str(INFOPLIST.relative_to(ROOT)))
                    + swift_keys_outside_copy(rows, DERIVED_KEYS)
                    + project_prompt_settings(rows))
        for problem in problems:
            print(problem)
        if problems:
            print(f"sync.py: {len(problems)} problem(s); run tools/l10n/sync.py to regenerate")
            return 1
        print(f"sync.py: {len(localizable['strings'])} and {len(infoplist['strings'])} strings up to date")
        return 0

    LOCALIZABLE.write_text(dump(localizable), encoding="utf-8")
    INFOPLIST.write_text(dump(infoplist), encoding="utf-8")
    print(f"wrote {LOCALIZABLE.relative_to(ROOT)} ({len(localizable['strings'])} strings) and "
          f"{INFOPLIST.relative_to(ROOT)} ({len(infoplist['strings'])} strings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
