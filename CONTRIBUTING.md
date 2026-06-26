# Contributing

This repository hosts two active codebases: the Java desktop app
(`./`) and the Flutter mobile app (`lizzie_mobile/`).

## General

1. Keep PRs focused. One feature or fix per PR.
2. If you're unsure about a new feature, open an issue first to discuss
   before writing code.
3. The CI matrix is described in the root `README.md` under
   "Contributing". Make sure the relevant checks pass before requesting
   review.

## Java desktop

- Follow the
  [Java naming conventions](https://www.geeksforgeeks.org/java-naming-conventions/).
- The CI runs `mvn clean package` on Linux, macOS and Windows against
  JDK 11, 17 and 21 and enforces formatting via
  `mvn com.coveo:fmt-maven-plugin:check`. Apply formatting locally
  with `mvn com.coveo:fmt-maven-plugin:format`.
- Most PRs will be merged. In doubt, open an issue first — issues are
  free, your development time is not.

## Flutter mobile

- Code style is enforced by `dart format`; CI fails on
  unformatted code.
- The analyzer runs with `--no-fatal-infos` (info-level lints don't
  fail the build but should be addressed when practical).
- Tests live in `lizzie_mobile/test/`; add unit tests for any new
  logic in `lib/engine/`, `lib/go/`, or `lib/state/`.
- See `lizzie_mobile/README.md` for the project layout.

## Native katago for Android

- `lizzie-mobile/katago-mobile/src/`, `eigen/`, `models/`, and `out/`
  are gitignored — they are populated by the scripts under
  `lizzie-mobile/katago-mobile/scripts/`.
- The CI build is `workflow_dispatch` only (it's slow and produces a
  release artifact).
