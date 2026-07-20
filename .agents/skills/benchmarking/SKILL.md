---
name: benchmarking
description: Use this skill whenever the user mentions "voiceink", "VoiceInk", "fluidvoice", "FluidVoice", "typewhisper", "TypeWhisper", "referência", "referências", "inspiração", "benchmarking", "benchmark", or any reference to apps/projetos that serve as inspiration for Prisma. This skill provides canonical paths and cloning policy for reference projects.
---

# Benchmarking — Reference Projects

## Role

This skill owns the canonical knowledge about open-source reference projects that inspire Prisma.

## When to Use

Use this skill whenever the user mentions a known reference project (VoiceInk, FluidVoice, TypeWhisper), asks about benchmarking, talks about "apps referência" or "inspiração", or wants to solve/improve something by studying similar apps.

## Scope Boundaries

- Use this skill to identify, classify, locate, and consult reference projects for benchmarking.
- Delegate to `../architecture/SKILL.md` when the focus is analyzing and adopting specific architecture patterns from a reference.
- Delegate to `../macos-app-engineering/SKILL.md` when the focus is UI/UX pattern extraction or macOS UI implementation.
- Delegate to `../audio-realtime/SKILL.md` when the focus is audio pipeline analysis.
- This skill does not implement changes — it directs agents to the right reference code and context.

## Reference Classification

Every reference must be classified into one or more categories when added:

| Category | Description |
|----------|-------------|
| **UI/UX** | Reference for user experience, interaction design, visual polish, or motion — even if the app does something entirely different from Prisma |
| **Same-domain** | App that does the same thing as Prisma (meeting capture, transcription, voice-to-text, audio processing, etc.) |

A reference can be **UI/UX**, **Same-domain**, or **Both**.

## Reference Directory Layout

All open-source reference clones live under a single shared folder, separate from personal projects:

| Scope | Path |
|-------|------|
| **Absolute** | `~/Documents/Projects/References/` |
| **From Prisma (vozinha)** | `../References/` |

Personal projects stay as siblings of `References/` in `~/Documents/Projects/`. Never clone reference repos directly into the Projects root.

## Registered References

### voiceink / VoiceInk

| Attribute | Value |
|-----------|-------|
| **Canonical name** | VoiceInk |
| **Classification** | Both (UI/UX + Same-domain) |
| **Local path** | `../References/VoiceInk/` |
| **Cloned?** | ✅ Yes |
| **Description** | macOS app for voice transcription; relevant architecture, audio pipeline, and UI patterns |

### fluidvoice / FluidVoice

| Attribute | Value |
|-----------|-------|
| **Canonical name** | FluidVoice |
| **Classification** | Same-domain |
| **Local path** | `../References/FluidVoice/` |
| **Cloned?** | ✅ Yes |
| **Remote** | https://github.com/altic-dev/FluidVoice/ |
| **Description** | Open-source reference for fluid voice UI and audio interactions |

### typewhisper / TypeWhisper

| Attribute | Value |
|-----------|-------|
| **Canonical name** | TypeWhisper |
| **Classification** | Same-domain |
| **Local path** | `../References/TypeWhisper/` |
| **Cloned?** | ✅ Yes |
| **Remote** | https://github.com/TypeWhisper/typewhisper-mac |
| **Description** | macOS app for voice-to-text; useful reference for transcription workflows |

## Clone Policy

When a reference project is **not cloned locally** (tagged ❌):

1. **Ask the user** if they want to clone it before proceeding with any analysis that depends on the reference.
2. **Clone location**: always `~/Documents/Projects/References/<CanonicalName>/`. Use the canonical PascalCase name for the target directory.
3. Use `git clone <remote_url> <target_path>` with the canonical PascalCase name for the target directory.
4. After cloning, update the **Registered References** table above with the local path and mark **Cloned?** as ✅ Yes.

## Consultation Methods (Priority Order)

When studying a reference, use this priority order. Start with #1 and fall back as needed.

### 1. Local (preferred)
Clone is available — browse files directly with `Read`, `Glob`, `Grep`, `Bash`. Fastest and most reliable.

### 2. DeepWiki
When a repository has a DeepWiki page, use `WebFetch` to get an AI-friendly summary of its architecture, key files, and conventions. Useful for broad context before diving into details.

Format: `https://deepwiki.ai/<owner>/<repo>`

### 3. Remote repository web UI
Fetch files via `WebFetch` from GitHub/GitLab/Bitbucket raw URLs or the web interface:
- Raw content: `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>`
- API: `https://api.github.com/repos/<owner>/<repo>/contents/<path>`
- Web: `https://github.com/<owner>/<repo>`

`gh` CLI is also available for GitHub-specific operations (issues, PRs, file listings).

### 4. grep.app
For cross-repository pattern search, use `WebFetch` on `https://grep.app/search?q=<query>` or `WebSearch` to find how other projects implement a specific pattern. Useful when you need to search beyond the registered references.

## How to Use References for Benchmarking

When the user wants to solve or improve something, use the classification to pick the right references:

1. **If the problem is UI/UX-related** (layout, animations, interactions, visual polish): consult references classified as **UI/UX** first. Even if they do something different, their UI patterns may inspire the solution.

2. **If the problem is domain-related** (audio capture, transcription, meeting workflows, data persistence): consult references classified as **Same-domain** first. They solve similar problems and may share architecture or pipeline patterns.

3. **If the problem touches both** (e.g., a transcription feature with a polished UI): consult references classified as **Both** — or consult UI/UX and Same-domain references together.

4. **Select the consultation method** following the priority order above:
   - ✅ **Cloned locally** → use Local.
   - ❌ **Not cloned** → try DeepWiki, then Remote Web, then grep.app. Ask the user whether to clone if deep analysis is needed.

5. Use the reference code as **inspiration only** — never copy-paste without understanding the license and adapting to Prisma's architecture.

6. Document any patterns adopted from references in the relevant PR or issue.

## Adding a New Reference

When a new reference project is identified:

1. Add it to the **Registered References** table above.
2. **Classify it** as UI/UX, Same-domain, or Both.
3. Fill in all attributes (canonical name, local path, remote URL, description).
4. Mark cloned status. If not cloned locally, the clone policy applies.

## Trigger Keywords

This skill activates on any of these mentions (case-insensitive partial match):

- `voiceink`, `VoiceInk`
- `fluidvoice`, `FluidVoice`
- `typewhisper`, `TypeWhisper`
- `referência`, `referências`, `inspiração`
- `benchmarking`, `benchmark`
- `apps referência`, `projetos referência`

## Related Skills

- `../architecture/SKILL.md` — when analyzing same-domain architecture patterns
- `../macos-app-engineering/SKILL.md` — when studying reference UI implementations or UI/UX decisions
- `../audio-realtime/SKILL.md` — when studying reference audio pipelines
- Global `thermo-nuclear-code-quality-review` — when reviewing changes inspired by references

## References

- `../architecture/SKILL.md`
- Global `thermo-nuclear-code-quality-review`
- `../macos-app-engineering/SKILL.md`
