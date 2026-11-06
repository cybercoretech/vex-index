# 🗂️ vex-index

The package index for the [Vex language](https://github.com/cybercoretech/vexlang).

It is one file, [`index.json`](index.json). There is no registry server and no
account to create. Publishing a package version means opening a pull request
that adds an entry here, and CI verifies every new tarball before it can merge.

## 📥 Using packages

```sh
vexlang add NAME@VERSION              # downloads NAME-VERSION.tar.gz into .
vexlang add NAME@VERSION --out vendor
```

`vexlang` reads this index from
`https://raw.githubusercontent.com/cybercoretech/vex-index/main/index.json` by
default. Override that with `--index URL|PATH` or `VEX_INDEX`. Every download
is checked against the size and SHA-256 recorded here, and nothing is written
if either one doesn't match.

## 📤 Publishing a version

1. **Build** the tarball from your project's `vex.toml`:
   ```sh
   vexlang package            # -> dist/NAME-VERSION.tar.gz (reproducible)
   ```
2. **Host** it at a stable `https://` URL. A GitHub release asset on your own
   repository works well:
   ```sh
   gh release create vVERSION dist/NAME-VERSION.tar.gz
   ```
3. **Record** it in a fork/clone of this repository:
   ```sh
   vexlang publish --index ../vex-index \
     --url https://github.com/OWNER/REPO/releases/download/vVERSION/NAME-VERSION.tar.gz \
     --description "One line about the package"
   ```
4. **Open a pull request** with the `index.json` change. CI downloads the
   tarball and checks its size and SHA-256.

## 📐 Format

```json
{
  "schema": 1,
  "packages": {
    "mypkg": {
      "description": "One line about the package",
      "versions": {
        "0.1.0": {
          "url": "https://github.com/OWNER/REPO/releases/download/v0.1.0/mypkg-0.1.0.tar.gz",
          "sha256": "64 lowercase hex characters",
          "size": 1234
        }
      }
    }
  }
}
```

## 🧊 Rules

- **Names and versions** use only letters, digits, `.`, `_`, `-` and `+`, and
  don't start with `.` or `-`.
- **URLs must be `https://`** and tarballs at most 64 MiB.
- **Published versions are immutable.** A version can't be edited, deleted or
  re-pointed after it merges, and the hosted file must never change.
- **Yanking:** to withdraw a broken version, set `"yanked": true` on it.
  `vexlang add` refuses yanked versions. Yanking can't be undone.
- **Package names** are first come, first served. Changes to an existing
  package must come from its original publisher or a maintainer.

## 🛠️ Checking locally

```sh
scripts/validate.sh                          # structure only
git show origin/main:index.json > /tmp/base.json
scripts/validate.sh /tmp/base.json           # + immutability and downloads
```

Needs `bash`, `jq`, `curl` and `sha256sum`.

## 🔐 Security

Report a malicious or compromised package to security@cybercoretech.net.

---

👻 Code & Design by Darkstardevx
