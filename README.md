# stealthx

`stealthx` is a macOS overlay app for online real-time transcript capture and fast follow-up actions.

## Current flow

- capture a speaker-side transcript from the app UI
- show the transcript live in a read-only transcript panel
- request an answer from the transcript
- copy or clear the current transcript

At the moment, the transcript path is intentionally mocked in the UI with a hard-coded speaker-to-text stream so the backend handoff is clear. The product direction is speaker-output transcription, not microphone dictation. The current GUI is therefore a backend-poc wiring target: the interface already shows the intended transcript and answer flow even though the speaker-to-text events are still mocked.

## Planned product shape

The intended flow is:

1. start speaker-to-text transcription
2. stream transcript text live into the app
3. request an answer from the transcript
4. support capture and operator actions around that transcript

## Planned actions

Two buttons in the current UI are placeholders have been implemented:

- `Screenshot`: capture the current screen or relevant visible content
- `Mimic Type`: type whatever text is currently held in the clipboard

The longer-term direction around these actions is a share-safe mirror window flow, where a separate mirrored window can be shown while excluding the private window we do not want to expose.

## Reference work

Related implementation work already exists in the commit history of:

- [1darshanpatil/macxctl](https://github.com/1darshanpatil/macxctl)

That repo already contains prior exploration for:

- speaker/render-side live transcript pipelines
- sanitized share mirror windows
- clipboard transport and typing-adjacent operator flows

For this project, that earlier work should be treated as the reference backend-poc source for future GUI wiring.

## Repository Habits

This repo uses the promotion flow documented in [BRANCHING.md](./BRANCHING.md).

- `dev -> stg -> prod`

### Branch naming

- long-lived environment branches:
  - `dev`
  - `stg`
  - `prod`
  - `main`
- active development branches:
  - `dev/<identity>/<topic>`
- optional contributor staging branches when needed:
  - `stg/<identity>`

Examples:

- `dev/ved/transcript-answer-flow`
- `dev/ved/screenshot-mimic-type`
- `stg/ved`

### Typical flow

1. branch from `dev` into a working branch such as `dev/<identity>/<topic>`
2. commit work there until the feature is ready
3. merge or promote that work back into `dev`
4. raise `dev -> stg` when the approved development state should be staged
5. promote `stg -> prod` when staging is approved
6. merge the production-approved line into `main`

### Useful commands

Create a working branch from `dev`:

```bash
git switch dev
git pull
git switch -c dev/<identity>/<topic>
```

Push the working branch:

```bash
git push -u origin dev/<identity>/<topic>
```

Promote the current development line into staging with a PR:

```bash
git switch dev
git push -u origin dev
git switch stg
git push -u origin stg
gh pr create --base stg --head dev --title "Promote dev to stg"
```

Promote staging into production with a PR:

```bash
gh pr create --base prod --head stg --title "Promote stg to prod"
```

### Commit message format

Follow standard conventional-style commit messages with a short type and a focused summary.

Recommended types:

- `feat`: new functionality
- `fix`: bug fix
- `chore`: repository or maintenance work
- `docs`: documentation
- `refactor`: internal restructuring without changing intended behavior
- `style`: visual or formatting-only change
- `test`: test-related change

Examples:

- `feat(transcript): add answer action placeholder`
- `fix(window): keep overlay visible above fullscreen apps`
- `style(ui): adopt system macOS control theme`
- `chore(repo): remove tracked Xcode metadata`
- `docs(readme): document branch and promotion habits`
