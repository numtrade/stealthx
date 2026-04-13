# Branching Model

This repo uses a simple promotion flow:

`dev -> stg -> prod`

## Branch roles

- `dev`: active development branch. New features, UI changes, and integration work land here first.
- `stg`: staging branch. Promote tested work from `dev` here for broader validation.
- `prod`: production branch. Only stable, approved changes are promoted here.

## Promotion habit

1. Build and verify changes on `dev`.
2. Promote the exact tested commit from `dev` to `stg`.
3. After staging approval, promote the exact `stg` commit to `prod`.

## Current repo intent

- `main` remains available, but the working branch flow should use `dev`, `stg`, and `prod`.
- The current UI/theme work is intended to live on `dev`.
