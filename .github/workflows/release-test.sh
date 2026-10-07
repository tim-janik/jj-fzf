#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail

scripts=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unset GITHUB_REF_TYPE GITHUB_REF_NAME GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
unset DOCKER_IMAGE DOCKER_ENV DOCKER_PLATFORM
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p "$work/repo/.github/workflows" "$work/bin"
cp "$scripts/gh-release.sh" "$work/repo/.github/workflows/"
cd "$work/repo"
git init -q --initial-branch=trunk
git config user.name 'Release Test'
git config user.email release-test@example.invalid
git remote add origin git@example.invalid:owner/example.git
cp "$scripts"/../../{.gitattributes,.version} .
git add .; git commit -qm baseline; git tag v0.0.0
printf '# NEWS\n\n## 0.1.0-rc.5\n\nCandidate notes.\n\n## 0.0.0\n\nOld notes.\n' > NEWS.md
git add NEWS.md; git commit -qm 'Add release notes'
git tag -a v0.1.0-rc.5 -m candidate
git commit -qm 'Nightly work' --allow-empty
git tag v0.1.0-nightly.1

export GH_TEST_LOG="$work/gh.log" GH_TEST_NOTES="$work/notes" DOCKER_TEST_LOG="$work/docker.log"
cat > "$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$@" >> "$GH_TEST_LOG"
while [[ $# -gt 0 ]]; do
  [[ $1 != --notes-file ]] || cp "$2" "$GH_TEST_NOTES"
  shift
done
exit "${GH_TEST_STATUS:-0}"
EOF
cat > "$work/bin/make" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${1-} == distcheck ]]
if [[ ${FAKE_MAKE_STATUS:-0} != 0 ]]; then
  echo 'make: simulated failure' >&2
  exit "$FAKE_MAKE_STATUS"
fi
tag=$(git archive HEAD .version | tar -xOf - | cut -d' ' -f1)
version=${tag#v}
rm -rf artifacts && mkdir artifacts
printf 'Test archive\n' > "artifacts/example-$version.tar.xz"
(cd artifacts && sha256sum "example-$version.tar.xz" > "example-$version.SHA256SUMS")
if [[ -n ${FAKE_MAKE_BADSUM-} ]]; then
  printf 'Tampered\n' >> "artifacts/example-$version.tar.xz"
fi
EOF
cat > "$work/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$@" >> "$DOCKER_TEST_LOG"
args=("$@")
for i in "${!args[@]}"; do
  [[ ${args[i]} != make ]] || exec "${args[@]:i}"
done
EOF
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

expect_failure()
{
  if "$@" > "$work/failure" 2>&1; then
    echo "Expected failure: $*" >&2
    exit 1
  fi
}

# First lightweight tag has no earlier release.
git checkout -q v0.0.0
.github/workflows/gh-release.sh v0.0.0 > "$work/echo"
grep -qE '(^| )--prerelease( |$)' "$work/echo"
grep -q baseline artifacts/.notes
[[ ! -s $GH_TEST_LOG ]]
# Annotated tag on its own commit: draft release with NEWS.md notes.
git checkout -q v0.1.0-rc.5
.github/workflows/gh-release.sh v0.1.0-rc.5 > "$work/echo"
grep -q 'gh release create' "$work/echo"
grep -q -- '--verify-tag' "$work/echo"
grep -qE '(^| )--draft( |$)' "$work/echo"
grep -q 'Candidate notes.' "$work/echo"
expect_failure grep -q 'Old notes.' "$work/echo"
[[ ! -s $GH_TEST_LOG ]]
.github/workflows/gh-release.sh --upload v0.1.0-rc.5
[[ $(grep -cx create "$GH_TEST_LOG") == 1 ]]
grep -qx -- '--verify-tag' "$GH_TEST_LOG"
grep -qx -- '--draft' "$GH_TEST_LOG"
grep -qxi 'example 0.1.0-rc.5' "$GH_TEST_LOG"
grep -qx 'Candidate notes.' "$GH_TEST_NOTES"
expect_failure grep -q 'Old notes.' "$GH_TEST_NOTES"
printf '## 0.1.0-rc.50\n' > NEWS.md
expect_failure env FAKE_MAKE_STATUS=3 .github/workflows/gh-release.sh v0.1.0-rc.5
grep -q 'NEWS mismatch' "$work/failure"
rm NEWS.md
expect_failure env FAKE_MAKE_STATUS=3 .github/workflows/gh-release.sh v0.1.0-rc.5
grep -q 'NEWS mismatch' "$work/failure"

# Lightweight tag on the trunk tip: prerelease with git-log notes.
git checkout -q -- NEWS.md
git checkout -q trunk
: > "$GH_TEST_LOG"
.github/workflows/gh-release.sh v0.1.0-nightly.1 > "$work/echo"
grep -q 'gh release create' "$work/echo"
grep -qE '(^| )--prerelease( |$)' "$work/echo"
grep -q 'Nightly work' "$work/echo"
expect_failure grep -q 'Add release notes' "$work/echo"
expect_failure grep -q baseline "$work/echo"
[[ ! -s $GH_TEST_LOG ]]
.github/workflows/gh-release.sh --upload v0.1.0-nightly.1
[[ $(grep -cx create "$GH_TEST_LOG") == 1 ]]
grep -qx -- '--prerelease' "$GH_TEST_LOG"
grep -qxi 'example 0.1.0-nightly.1' "$GH_TEST_LOG"
grep -q 'Nightly work' "$GH_TEST_NOTES"
expect_failure grep -q baseline "$GH_TEST_NOTES"

: > "$GH_TEST_LOG"
git tag -a v0.1.0-nightly.2 -m 'second tag'
expect_failure env FAKE_MAKE_STATUS=3 .github/workflows/gh-release.sh --upload v0.1.0-nightly.1
grep -qF 'differs from version tag v0.1.0-nightly.2' "$work/failure"
[[ ! -s $GH_TEST_LOG ]]
git tag -d v0.1.0-nightly.2 > /dev/null

# Docker mode: each DOCKER_ENV item gets its own --env, image precedes the command.
: > "$GH_TEST_LOG"
export DOCKER_IMAGE='example-ci:latest' DOCKER_ENV='GOPATH=/tmp/go GOCACHE=/tmp/go-build'
.github/workflows/gh-release.sh --docker --upload v0.1.0-nightly.1
[[ $(grep -B1 -x 'GOPATH=/tmp/go' "$DOCKER_TEST_LOG" | head -n1) == --env ]]
[[ $(grep -cx -- '--env' "$DOCKER_TEST_LOG") == 4 ]]
grep -qx 'GOCACHE=/tmp/go-build' "$DOCKER_TEST_LOG"
[[ $(tail -n3 "$DOCKER_TEST_LOG") == $'example-ci:latest\nmake\ndistcheck' ]]
[[ $(grep -cx create "$GH_TEST_LOG") == 1 ]]
unset DOCKER_IMAGE DOCKER_ENV

: > "$GH_TEST_LOG"
expect_failure env GH_TEST_STATUS=9 .github/workflows/gh-release.sh --upload v0.1.0-nightly.1
[[ $(grep -cx create "$GH_TEST_LOG") == 1 ]]
expect_failure grep -Eq '^(list|delete|upload|api)$' "$GH_TEST_LOG"
: > "$GH_TEST_LOG"
expect_failure env FAKE_MAKE_BADSUM=1 .github/workflows/gh-release.sh --upload v0.1.0-nightly.1
[[ ! -s $GH_TEST_LOG ]]
expect_failure env FAKE_MAKE_STATUS=3 .github/workflows/gh-release.sh --upload v0.1.0-nightly.1
expect_failure .github/workflows/gh-release.sh v0.0.0
expect_failure .github/workflows/gh-release.sh --docker v0.1.0-nightly.1
[[ ! -s $GH_TEST_LOG ]]
echo 'Release tests passed.'
