# Branching Model

This repo uses a promotion-first workflow:

`dev -> stg -> prod -> main`

## Long-lived branches

- `dev`: active integration branch. New feature work is promoted here first.
- `stg`: staging branch. Approved `dev` state is promoted here for broader validation.
- `prod`: production candidate branch. Approved `stg` state is promoted here next.
- `main`: final stable line after production-ready promotion.

## Working branch naming

Use personal feature branches under `dev`:

- `dev/<identity>/<topic>`

Optional personal staging branches can also be used when needed:

- `stg/<identity>`

Examples:

- `dev/ved/transcript-answer-flow`
- `dev/ved/sanitized-mirror-window`
- `stg/ved`

## Promotion habit

1. Start from `dev`.
2. Create a working branch as `dev/<identity>/<topic>`.
3. Commit and verify changes there.
4. Merge or promote that work back into `dev`.
5. Raise a PR from `dev` into `stg`.
6. After staging approval, raise a PR from `stg` into `prod`.
7. After production approval, merge the approved line into `main`.

## Commands

Create a new working branch from `dev`:

```bash
git switch dev
git pull
git switch -c dev/<identity>/<topic>
```

Push the working branch:

```bash
git push -u origin dev/<identity>/<topic>
```

Promote `dev` into `stg`:

```bash
git push -u origin dev
git push -u origin stg
gh pr create --base stg --head dev --title "Promote dev to stg"
```

Promote `stg` into `prod`:

```bash
git push -u origin prod
gh pr create --base prod --head stg --title "Promote stg to prod"
```

Promote `prod` into `main`:

```bash
git push -u origin main
gh pr create --base main --head prod --title "Promote prod to main"
```

## Commit message format

Use conventional-style commit messages with a clear type prefix.

Recommended types:

- `feat`
- `fix`
- `chore`
- `docs`
- `refactor`
- `style`
- `test`

Examples:

- `feat(transcript): add answer action placeholder`
- `fix(window): keep overlay visible above fullscreen apps`
- `chore(repo): remove tracked Xcode metadata`
- `docs(branching): document promotion workflow`
