# Handbook — <repo-name>

Infrastructure and deploy reference. For how to contribute see [GUIDEBOOK.md](GUIDEBOOK.md).

## TL;DR

- **Push to `main`** → production (`<domain>`)
- **Push to any other branch** → staging (`<staging-domain>`)
- **Required CI** on PR to `main`: `<checks>`
- **Branch protection** on `main`: PR required, green checks required

## Environments

| | URL | Database | Notes |
|---|---|---|---|
| production | | | |
| staging | | | |

## Deploy

<How it gets there. Which command, from which directory, and what a false green looks like.>

## Secrets

<Where they live — never the values. Which ones exist and who sets them.>

## Backups

<Schedule, destination, retention. And when a restore was last tested.>

## Runbooks

| Situation | What to do |
|---|---|
| | |
