# ProJobFlo Release Versioning

## Current Version

The current app version is defined in `app.html`:

```js
const APP_VERSION = "1.0.0-beta.2";
```

The version displays in:

- Settings
- Application Health & Support

## Versioning Rule

Future app releases should require changing only:

- `APP_VERSION`

Optional release metadata:

- `APP_RELEASE_COMMIT`

`APP_RELEASE_COMMIT` is currently blank because the static app does not have a build step that injects git metadata.

## Suggested Version Format

Use semantic prerelease versions:

- `1.0.0-beta.1`
- `1.0.0-beta.2`
- `1.0.0-rc1`
- `1.0.0`

Recommended meaning:

- `beta`: controlled contractor testing, support expected.
- `rc`: release candidate after beta blockers are resolved.
- no suffix: public production release.

## Release Checklist

For every release:

1. Update `APP_VERSION`.
2. Run `git diff --check`.
3. Parse `app.html`.
4. Parse `approve.html`.
5. Run the production smoke test.
6. Run Settings health check.
7. Copy support report and confirm the version is correct.
8. Confirm no sensitive data appears in the report.
9. Commit with a release-focused message.
10. Push only after approval.

## Why Versioning Matters

Support reports include the app version so Hayden can connect contractor issues to the deployed code. This matters when:

- a contractor reports a stale browser cache
- a rollback happens
- two beta users are on different loaded versions
- a support report needs to match a git commit

## Future Improvement

Before paid launch, consider adding a build/deploy step that writes the git commit SHA into `APP_RELEASE_COMMIT` automatically.
