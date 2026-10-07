#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail && SCRIPTNAME=${0##*/} && die() { [ -z "$*" ] || echo "$SCRIPTNAME: $*" >&2; exit 127 ; }

# Usage: gh-release.sh [-x] [--docker] [--upload] [TAG]
# Build assets via `make distcheck` (docker: DOCKER_IMAGE, DOCKER_ENV,
# DOCKER_PLATFORM) and create a GitHub release: lightweight tags give public
# prereleases, annotated tags drafts, echoed unless --upload. Projects
# provide `make distcheck` filling ./artifacts/ incl. $PROJECT-$VERSION.SHA256SUMS.
# Release-critical files:
#   .version .gitattributes export-subst bakes version & date into source archives
#   Makefile                version & date, dist, distcheck
#   NEWS.md                 notes for annotated (draft) releases
#   gh-release.sh           builds assets, creates the GitHub release
#   ci.yml                  Release job runs this script

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not inside a git repository'
cd "$ROOT"

# Options and release tag.
DOCKER=
UPLOAD=
TAG=${GITHUB_REF_NAME:-}
while test $# -ne 0 ; do
  case "$1" in \
    -x)		set -x ;;
    --docker)	DOCKER=1 ;;
    --upload)	UPLOAD=1 ;;
    -*)		die "unknown option: $1" ;;
    *)		TAG="$1" ;;
  esac
  shift
done
VERSION_TAG=$(git archive HEAD .version | tar -xOf - | cut -d' ' -f1)
TAG=${TAG:-$VERSION_TAG}
[[ $TAG == v[0-9]*.[0-9]* && $TAG =~ ^v[0-9][a-zA-Z0-9.+_-]*$ ]] || die "invalid release tag: $TAG"
[[ $(git rev-parse "refs/tags/$TAG^{commit}") == "$(git rev-parse HEAD)" ]] || die "$TAG does not point to HEAD"
[[ $TAG == "$VERSION_TAG" ]] || die "$TAG differs from version tag $VERSION_TAG"
VERSION=${TAG#v}

# Project name from .git/config or checkout directory.
PROJECT=$(git config --local --get remote.origin.url || :)
PROJECT=${PROJECT%/}; PROJECT=${PROJECT##*/}; PROJECT=${PROJECT##*:}; PROJECT=${PROJECT%.git}
PROJECT=${PROJECT:-${PWD##*/}}
TITLE="${PROJECT^^} $VERSION"

extract_version()
(
  sed -nr '/^##? /s/^#+( [a-zA-Z_0-9-]+)? v?([0-9]\.[0-9][^ ]*)( .*)?$/\2/p' "$1" | head -1
)

# PRERELEASE for lightweight tags, DRAFT for annotated.
KIND=--prerelease
[[ $(git cat-file -t "refs/tags/$TAG") != tag ]] || KIND=--draft
[[ $KIND != --draft || $(extract_version NEWS.md) == "$VERSION" ]] || die 'NEWS mismatch'

# Build release assets, in docker if requested.
if [[ $DOCKER ]]; then
  [[ -n ${DOCKER_IMAGE-} ]] || die 'missing DOCKER_IMAGE for --docker'
  read -ra docker_envs <<<"${DOCKER_ENV-}"
  # Caches under /tmp are writable for any container user, fill in if missing.
  [[ ${docker_envs[*]-} == *GOPATH=* ]] || docker_envs+=(GOPATH=/tmp/go)
  [[ ${docker_envs[*]-} == *GOCACHE=* ]] || docker_envs+=(GOCACHE=/tmp/go-build)
  mounts=(--volume "$PWD:$PWD")
  # Mount external Git metadata for worktrees too.
  if git_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    mounts+=(--volume "$git_dir:$git_dir:ro")
  fi
  env_args=(--env TZ=UTC --env LC_ALL=C)
  for kv in "${docker_envs[@]}" ; do env_args+=(--env "$kv") ; done
  docker run --rm --platform "${DOCKER_PLATFORM:-linux/amd64}" --user "$(id -u):$(id -g)" \
    "${mounts[@]}" --workdir "$PWD" "${env_args[@]}" \
    "$DOCKER_IMAGE" make distcheck
else
  make distcheck
fi

# Verify release artifacts; make distcheck must have built $VERSION assets.
[[ -f "artifacts/$PROJECT-$VERSION.SHA256SUMS" ]] ||
  die "missing artifacts/$PROJECT-$VERSION.SHA256SUMS; make distcheck must build $VERSION artifacts"
( cd artifacts && sha256sum -c "$PROJECT-$VERSION.SHA256SUMS" )

# NEWS, extract the first version entry for annotated tags, extract_version()
# accepts '##? v1.2 .*' style headings. Dotfiles in artifacts/* are ignored.
if [[ $KIND == --draft ]]; then
  [[ -f NEWS.md ]] || die 'Annotated release tags require NEWS.md'
  awk -v V="$VERSION" '
    /^##? / {
      if (found) exit
      for (i = 1; i <= NF; i++) { s = $i; sub(/^v/, "", s); if (s == V) break }
      if (i > NF) next
      found = 1
    }
    found { print }
    END { if (!found) exit 1 }
  ' NEWS.md > artifacts/.notes || die "First NEWS.md entry must match $VERSION"
else
  # Grab recent git log for lightweight tags.
  PREVIOUS=$(git describe --tags --abbrev=0 --match='v[0-9]*.[0-9]*' HEAD^ 2>/dev/null || true)
  {
    echo "# $TITLE"
    echo
    echo 'Development version - may contain bugs or compatibility issues.'
    echo
    echo '``````````````````````````````````````````````````````````````````````````````````````'
    git log --pretty='%s    # %cd %an %h%n%w(0,4,4)%b' \
	--first-parent --date=short "${PREVIOUS:+$PREVIOUS..}HEAD" |
      sed -e '/^\s*Signed-off-by:.*<.*@.*>/d' |
      sed '/^\s*$/{ N; /^\s*\n\s*$/D }'
    echo '``````````````````````````````````````````````````````````````````````````````````````'
    echo
  } > artifacts/.notes
fi

# INFO
echo "TITLE: $TITLE"
echo "TAG: $TAG"
echo "VERSION: $VERSION"
echo "KIND: $KIND"
echo "ARTIFACTS:" && ls -l artifacts/*
echo "NOTES:" && cat artifacts/.notes

# Create Github release for remote tag.
gh_cmd=(gh release create
	--title "$TITLE"
	--notes-file artifacts/.notes
	"$KIND"
	--verify-tag
	"$TAG"
	artifacts/*)
if [[ $UPLOAD ]]; then
  "${gh_cmd[@]}" </dev/null
else
  echo "+ ${gh_cmd[*]}"
fi

# gh env vars: https://cli.github.com/manual/gh_help_environment
