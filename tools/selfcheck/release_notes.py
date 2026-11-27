#!/usr/bin/env python3
"""Generate structured Chinese GitHub Release notes from CHANGELOG.md and git history.

Always ensures every Release clearly lists what changed:
1. Optional manual notes passed via workflow_dispatch (--extra-notes).
2. Curated section matching `## <tag>` in CHANGELOG.md (preferred human-readable summary).
3. Automatic git commit log since the previous `v*` tag (either as a collapsible appendix
   when CHANGELOG.md exists, or as the primary categorized changelog when CHANGELOG.md
   does not have an entry for the tag).
4. Standardized build, checksum, and installation metadata.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def run_git(args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def extract_changelog_section(changelog_path: Path, tag: str) -> str:
    if not changelog_path.is_file():
        return ""
    lines = changelog_path.read_text(encoding="utf-8").splitlines()
    heading_re = re.compile(rf"^##\s+{re.escape(tag)}(?:\s|$|\()")
    next_heading_re = re.compile(r"^##\s+")
    capturing = False
    collected: list[str] = []
    for line in lines:
        if capturing:
            if next_heading_re.match(line):
                break
            collected.append(line)
        elif heading_re.match(line):
            capturing = True
    return "\n".join(collected).strip()


def find_previous_tag(current_tag: str, head_sha: str) -> str:
    # Only consider tags reachable from HEAD (excluding current_tag), sorted newest version first.
    raw = run_git(["tag", "--list", "v*", "--sort=-version:refname", "--merged", head_sha])
    tags = [t.strip() for t in raw.splitlines() if t.strip() and t.strip() != current_tag]
    return tags[0] if tags else ""


def collect_commits(prev_tag: str, head_sha: str) -> list[tuple[str, str, str]]:
    rev_range = f"{prev_tag}..{head_sha}" if prev_tag else head_sha
    max_count = [] if prev_tag else ["-n", "15"]
    raw = run_git(
        ["log", rev_range, *max_count, "--no-merges", "--pretty=format:%H\x1f%h\x1f%s"]
    )
    commits: list[tuple[str, str, str]] = []
    for line in raw.splitlines():
        parts = line.split("\x1f", 2)
        if len(parts) == 3:
            commits.append((parts[0], parts[1], parts[2].strip()))
    return commits


def format_categorized_commits(
    commits: list[tuple[str, str, str]], server_url: str, repo: str
) -> str:
    buckets: dict[str, list[str]] = {
        "新增功能": [],
        "问题修复": [],
        "优化与调整": [],
    }
    prefix_re = re.compile(r"^([a-zA-Z]+)(?:\([^)]+\))?!?:\s*(.+)$")
    for full_sha, short_sha, subject in commits:
        link = f"[`{short_sha}`]({server_url}/{repo}/commit/{full_sha})"
        m = prefix_re.match(subject)
        if m:
            kind = m.group(1).lower()
            desc = m.group(2).strip()
            if kind == "feat":
                buckets["新增功能"].append(f"- {desc}（{link}）")
            elif kind == "fix":
                buckets["问题修复"].append(f"- {desc}（{link}）")
            else:
                buckets["优化与调整"].append(f"- {desc}（{link}）")
        else:
            buckets["优化与调整"].append(f"- {subject}（{link}）")

    sections: list[str] = []
    for title in ("新增功能", "问题修复", "优化与调整"):
        items = buckets[title]
        if items:
            sections.append(f"### {title}\n" + "\n".join(items))
    return "\n\n".join(sections)


def format_commit_list(
    commits: list[tuple[str, str, str]], server_url: str, repo: str
) -> str:
    return "\n".join(
        f"- [`{short_sha}`]({server_url}/{repo}/commit/{full_sha}) {subject}"
        for full_sha, short_sha, subject in commits
    )


def build_notes(args: argparse.Namespace) -> str:
    changelog_section = extract_changelog_section(Path(args.changelog), args.tag)
    prev_tag = args.prev_tag if args.prev_tag is not None else find_previous_tag(args.tag, args.sha)
    commits = collect_commits(prev_tag, args.sha)

    parts: list[str] = ["## 更新内容"]

    extra = (args.extra_notes or "").strip()
    if extra:
        parts.append(extra)

    if changelog_section:
        parts.append(changelog_section)
    elif commits:
        parts.append(format_categorized_commits(commits, args.server_url, args.repo))
    elif not extra:
        parts.append("- 同步最新 `main` 分支代码并重新构建自检包。")

    if commits:
        compare_line = ""
        if prev_tag:
            compare_url = f"{args.server_url}/{args.repo}/compare/{prev_tag}...{args.tag}"
            compare_line = f"\n\n完整代码对比：[`{prev_tag}...{args.tag}`]({compare_url})"

        if changelog_section:
            commit_lines = format_commit_list(commits, args.server_url, args.repo)
            parts.append(
                f"<details>\n<summary>查看本次提交记录（{len(commits)} 条）</summary>\n\n"
                f"{commit_lines}\n</details>{compare_line}"
            )
        elif compare_line:
            parts.append(compare_line.strip())

    short_sha = args.sha[:7]
    commit_url = f"{args.server_url}/{args.repo}/commit/{args.sha}"
    run_url = f"{args.server_url}/{args.repo}/actions/runs/{args.run_id}"

    build_info = f"""## 构建与安装信息

- 版本：{args.version} ({args.build})
- 代码：[`{short_sha}`]({commit_url})，main
- 工具：{args.xcode}，{args.sdk}，{args.arch} 的编译机
- 文件：`{args.ipa_name}`（{args.size}）
- SHA-256：`{args.sha256}`
- 这次构建：[#{args.run_number}]({run_url})

> 这是自检包：带自检页（首页标题按住两秒）和 30 张测试图，不是 App Store 包。IPA 不带签名，先用自签工具签名再装；系统需 iOS 26 或更新。每次 `main` 推送都会自动构建，版本号未变时会覆盖同标签 Release 文件。"""

    parts.append(build_info)
    return "\n\n".join(p.strip() for p in parts if p.strip()) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate GitHub Release notes.")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--server-url", default="https://github.com")
    parser.add_argument("--xcode", required=True)
    parser.add_argument("--sdk", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--ipa-name", required=True)
    parser.add_argument("--size", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--run-number", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--changelog", default="CHANGELOG.md")
    parser.add_argument("--prev-tag", default=None)
    parser.add_argument("--extra-notes", default="")
    parser.add_argument("--output", default="-")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    notes = build_notes(args)
    if args.output == "-":
        sys.stdout.write(notes)
    else:
        Path(args.output).write_text(notes, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
