---
name: git-workflow
description: This skill should be used when the user asks for Prisma Git operations such as creating a branch, committing, preparing a PR, merging safely, or using gh with multiline content.
---

# Git Workflow

## Role

Use this skill for Prisma-specific Git mechanics.

- Own branch, commit, PR, merge, and cleanup mechanics.
- Keep Git operations aligned with `AGENTS.md` lane policy.
- Use `gh --body-file` for multiline GitHub content.
- Do not teach generic Git unless it affects repository safety.

## Scope Boundary

- Use `../task-lifecycle/SKILL.md` for risk classification and lifecycle sequencing.
- Use `../quality-assurance/SKILL.md` for concrete validation commands and merge gates.
- Use `../code-review/SKILL.md` for review findings; it includes the mandatory structural pass.

## When to Use

Use this skill when creating/switching branches, committing, preparing PRs, merging, cleaning up branches, or sending multiline issue/PR text through `gh`.

## Prisma Rules

- Preserve unrelated worktree changes.
- Use Conventional Commits: `<type>(<optional-scope>): <summary>`.
- Keep commits atomic by intent: feature, fix, refactor, tests, docs, cleanup, review fix.
- Do not commit knowingly broken code.
- Before push/merge, run the lane gate selected by `task-lifecycle` and mapped by `quality-assurance`.
- Use PRs for non-trivial work unless the user explicitly chooses the direct local merge path.

## Standard Commands

```bash
git checkout main
git pull --ff-only
git checkout -b <type>/<short-topic>
```

```bash
git status --short
git diff --stat
git add <files>
git commit -m "<type>(<scope>): <summary>"
```

## GitHub CLI Body Safety

Use temporary files for multiline Markdown to avoid shell interpolation problems:

```bash
cat <<'EOF' >/tmp/prisma-gh-body.md
## Summary
- ...

## Verification
- ...
EOF
gh pr create --body-file /tmp/prisma-gh-body.md
gh issue comment <id> --body-file /tmp/prisma-gh-body.md
```

## Advanced Operations

For rebase, cherry-pick, bisect, or reflog recovery, use standard Git commands directly and preserve safety:

- inspect status first,
- avoid destructive commands unless the user explicitly requested them,
- prefer non-interactive commands,
- stop before rewriting shared history unless the intent is explicit.

## Related Skills

- `../task-lifecycle/SKILL.md`
- `../quality-assurance/SKILL.md`
- `../code-review/SKILL.md`
- `../thermo-nuclear-code-quality-review/SKILL.md`

## References

- `AGENTS.md`
