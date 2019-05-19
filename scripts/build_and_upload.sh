#!/bin/bash

# USAGE:
#   AWS_PROFILE=cfcommunity VERSION=0.0.1 ./scripts/build_and_upload.sh

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

set -eu

: ${VERSION:?required}

BUCKET=${BUCKET:-sample1-sidecar-buildpack}

echo "Building config-server-v${VERSION}"
(
  cd src/config-server-sidecar
  GOOS=linux GOARCH=amd64 go build -o "config-server-v${VERSION}" .
)

echo "Uploading to s3://${BUCKET}/config-server-sidecar/"
aws s3 cp \
  "src/config-server-sidecar/config-server-v${VERSION}" \
  "s3://${BUCKET}/config-server-sidecar/"

rm "src/config-server-sidecar/config-server-v${VERSION}"

echo "Path to download: https://s3.amazonaws.com/${BUCKET}/config-server-sidecar/config-server-v${VERSION}"

echo "Updating .version and .downloadurl"
echo $VERSION > $ROOT/.version
echo https://s3.amazonaws.com/${BUCKET}/config-server-sidecar/config-server-v${VERSION} > $ROOT/.downloadurl
