# Contributing to Sero

Sero is a small project, and contributions are welcome. A few things make one
land faster.

## Before writing code

For anything beyond a small fix, open an
[issue](https://github.com/surajbagal/sero/issues) first describing what you
want to change and why.

## New features: off until someone turns them on

Sero stays small by default. Anything new that changes how the browser looks
or behaves is:

- **minimal**: the smallest version that does the job, in the app's own quiet
  style;
- **optional, and off by default**: someone who never asks for it never sees
  it;
- **findable**: a switch in Settings.

Fixes and things every browser is expected to do don't need a switch.

## What tends to get merged

- **Small, focused changes.** One thing per pull request.
- **No new dependencies.** What Foundation, AppKit, SwiftUI or WebKit already
  do is used as it is.
- **The existing style.** Comments explain *why*, not what the next line does.
  No force-unwraps on anything that can plausibly fail.
- **A clean build.** `swift build` with no new warnings, and `swift test`
  passing.
- **A line in [CHANGELOG.md](CHANGELOG.md)** under Unreleased.

## What doesn't

- Anything that phones home, adds analytics, or sends anything new over the
  network without the person asking.
- A real key or token anywhere: in code, a test, an issue or a pasted log.

## Building and testing

```bash
./build.sh          # build/Sero.app, ad-hoc signed, runs on this Mac
swift test          # unit tests
```

`SERO_DEV=1 ./build.sh` makes a dev build on a yellow icon, named for its
branch. With Settings › General › Let a script drive Sero on, `./bench` drives
the running app over a local socket for testing; `./bench help` lists what it
can do.

## Reporting a bug

Open an issue with what you did, what you expected, what happened instead, and
your macOS version. A crash log, if there is one, is at
`~/Library/Application Support/Sero/crash.log`.
