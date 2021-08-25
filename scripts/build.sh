#!/bin/bash

set -e

cd app

TAG_COMMIT="$(git rev-list --abbrev-commit --tags --max-count=1)"
TAG="$(git describe --abbrev=0 --tags "${TAG_COMMIT}" 2>/dev/null || true)"

HEAD_COMMIT="$(git rev-parse --short HEAD)"
HEAD_COMMIT_DATE=$(git log -1 --format=%cd --date=format:'%Y%m%d')

BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD)"
RELEASE="FALSE"

if [ "$HEAD_COMMIT" == "$TAG_COMMIT" ]; then
	VERSION="$TAG"
    RELEASE="TRUE"
else
	VERSION="$TAG"-"$BRANCH_NAME"-"$HEAD_COMMIT"-"$HEAD_COMMIT_DATE"
fi

echo "#########################################################"
echo "# Branch Name: ${BRANCH_NAME}                            "
echo "# Release:     ${RELEASE}                                "
echo "# Tag:         ${TAG}                                    "
echo "# Tag Commit:  ${TAG_COMMIT}                             "
echo "# HEAD Commit: ${HEAD_COMMIT}                            "
echo "# HEAD Date:   ${HEAD_COMMIT_DATE}                       "
echo "# Version:     ${VERSION}                                "
echo "#########################################################"

[ -n "$BRANCH_NAME" ]      || { echo "BRANCH_NAME is required and not set, aborting..." >&2; exit 1; }
[ -n "$RELEASE" ]          || { echo "RELEASE is required and not set, aborting..." >&2; exit 1; }
[ -n "$TAG" ]              || { echo "TAG is required and not set, aborting..." >&2; exit 1; }
[ -n "$TAG_COMMIT" ]       || { echo "TAG_COMMIT is required and not set, aborting..." >&2; exit 1; }
[ -n "$HEAD_COMMIT" ]      || { echo "HEAD_COMMIT is required and not set, aborting..." >&2; exit 1; }
[ -n "$HEAD_COMMIT_DATE" ] || { echo "HEAD_COMMIT_DATE is required and not set, aborting..." >&2; exit 1; }
[ -n "$VERSION" ]          || { echo "VERSION is required and not set, aborting..." >&2; exit 1; }

if [[ $VERSION =~ ^[0-9]+\.[0-9]+ ]]; then
    _=${BASH_REMATCH[0]}
else
    echo "Version number failed validation: '$VERSION'"
    exit 1
fi

function echoMessage () {
    MESSAGE=$1
    printf "\n$MESSAGE"
}

function echoBlockMessage () {
  MESSAGE=$1
  printf "\n#########################################################"
  printf "\n# $MESSAGE"
  printf "\n#########################################################"
  printf "\n"
  printf "\n"
}

echoBlockMessage "restoring project"

dotnet restore \
    ./TSQLLint.Common/TSQLLint.Common.csproj \
    --verbosity m

echoBlockMessage "building project"

dotnet build \
    ./TSQLLint.Common/TSQLLint.Common.csproj \
    /p:Version="$VERSION" \
    --configuration Release \
    --no-restore

echoBlockMessage "restoring test project"

dotnet restore \
    ./TSQLLint.Common.Tests/TSQLLint.Common.Tests.csproj \
    --verbosity m

echoBlockMessage "running test project"

dotnet test \
    --no-restore \
    ./TSQLLint.Common.Tests/TSQLLint.Common.Tests.csproj

echoBlockMessage "packing project"

dotnet pack \
    ./TSQLLint.Common/TSQLLint.Common.csproj \
    -p:VERSION="$VERSION" \
    --configuration Release \
    --output /artifacts

if [ "$RELEASE" == "FALSE" ]; then
    echoMessage "Untagged commits are not pushed to Nuget"
    exit 0
fi

if [[ -z "$NUGET_API_KEY" ]]; then
    echoMessage "NUGET_API_KEY is not set in the environment."
    echoMessage "Artifacts will not be pushed to Nuget."
    exit 1
fi

echoBlockMessage "pushing to Nuget"

dotnet nuget push \
    "/artifacts/TSQLLint.Common.$VERSION.nupkg" \
    --api-key "$NUGET_API_KEY"  \
    --source https://api.nuget.org/v3/index.json
