# Git

## Branches

Never commit to `main` / `master` directly, even solo. A local hook blocks the
commit; server-side branch protection blocks the push.

Naming: `<type>/<short-description>`, where `<type>` matches the commit type.

```
feat/staging-environment      fix/cors-multi-tenant
chore/deps-bump               docs/deploy-runbook
```

For multi-batch work, stack branches from a base: `feat/x`, `feat/x-step1`.

## Commits — Conventional Commits with scope

```
<type>(<scope>): <past-tense subject, under 72 chars>

<optional body: the WHY, not the WHAT — the diff is the what>

Co-Authored-By: <model> <noreply@anthropic.com>
```

Types: `feat` `fix` `chore` `docs` `refactor` `test` `style` `perf` `build` `ci` `revert`

Scope is optional but preferred. Lowercase, slashes for nesting:

```
feat(auth): added refresh token rotation
fix(panels/sw): bumped CACHE_VERSION 19 to 24
chore(deps): bumped drizzle-orm 0.45.1 to 0.45.2
```

## Never

- Multi-purpose commits ("fixed bug AND refactored AND added tests") — split them
- Vague subjects: "update", "wip", "fix stuff"
- Present tense in the subject ("added", not "add" or "adds")
- `--amend` on a commit that has been pushed
- `--no-verify` to skip a hook. The hook is there for a reason
- Force-push to a shared branch

## Before committing

1. `git status` and `git diff` — see exactly what is staged
2. If anything looks surprising — large binaries, `.env*`, lockfile changes you
   didn't make, files outside the change — stop and say so
3. Stage files by name. Avoid `git add -A` unless asked
4. Show me the message before committing
5. Use a heredoc so formatting survives
6. `git status` afterwards to confirm

## Before pushing

1. `git remote -v` and `git branch --show-current`
2. Never push to `main` without an open PR, even if the server would allow it
3. Fresh branch: `-u origin <branch>` to set tracking

## When a hook rejects a commit

Do not bypass it. Read the error, fix the underlying issue, re-stage, and make a
new commit — not `--amend`, because the rejected commit never existed.

## At the end of a piece of work

Suggest the flow: branch → commit → PR. Never push to `main` directly, even if
branch protection is off.
