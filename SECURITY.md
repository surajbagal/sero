# Security

Sero handles your passwords, your history and every page you open, so a hole
in it matters more than most bugs. If you find one, please report it
privately first.

## How to report

Use the repository's **Security** tab ›
[**Report a vulnerability**](https://github.com/surajbagal/sero/security/advisories/new).
Only the maintainer sees it. Say what you found, where in the code, and how
to make it happen. A proof of concept that stays on your own machine is
welcome; please don't try it on other people's accounts or data.

Please don't open a public issue or pull request describing the problem until
a fixed version is out. A pull request that only fixes it, without spelling
out the attack, is fine.

## What counts

Anything that lets a web page, an extension, another app or someone on the
network do more than they should: read files, passwords, cookies or history,
get around a permission, open another app without asking, or change the app
itself. Sero's keychain items, its extensions layer and `./bench` are all in
scope.

A site that doesn't work, or an extension that behaves differently from
Chrome, is a bug rather than a security problem: open an
[issue](https://github.com/surajbagal/sero/issues) for those.
