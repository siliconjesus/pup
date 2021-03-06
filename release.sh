#!/bin/bash
# Requires go, rkt to be installed prior to running

VERSION="0.4.0"

rm -rf dist
mkdir dist

# Small test for rkt being installed
RKT=`which rkt` 
if [ "$?" -eq "1" ] 
then
	echo "rkt not installed. See https://coreos.com/rkt/docs/latest/distributions.html to install"
	exit 1
fi

for ENV in $( go tool dist list | grep -v 'android' | grep -v 'darwin/arm' | grep -v 's390x' | grep -v 'plan9/arm'); do
    eval $( echo $ENV | tr '/' ' ' | xargs printf 'export GOOS=%s; export GOARCH=%s\n' )

    GOOS=${GOOS:-linux}
    GOARCH=${GOARCH:-amd64}

    BIN="pup"
    if [ ${GOOS} == "windows" ]; then
        BIN="pup.exe"
    fi

    mkdir -p dist

    echo "Building for GOOS=$GOOS GOARCH=$GOARCH"

    sudo ${RKT} run \
        --set-env=GOOS=${GOOS} \
        --set-env=GOARCH=${GOARCH} \
        --set-env=CGO_ENABLED=0 \
        --volume pup,kind=host,source=${PWD} \
        --mount volume=pup,target=/go/src/github.com/ericchiang/pup \
        --insecure-options=image \
        docker://golang:1.6.3 \
        --exec go -- build -v -a \
        -o /go/src/github.com/ericchiang/pup/dist/${BIN} \
        github.com/ericchiang/pup

    sudo ${RKT} gc --grace-period=0s

	zip dist/pup_v${VERSION}_${GOOS}_${GOARCH}.zip -j dist/${BIN}
    rm -f dist/${BIN}
done

DARWIN_AMD64=pup_v${VERSION}_darwin_amd64.zip
DARWIN_386=pup_v${VERSION}_darwin_386.zip

cat << EOF > pup.rb
# This file was generated by release.sh
require 'formula'
class Pup < Formula
  homepage 'https://github.com/ericchiang/pup'
  version '0.4.0'

  if Hardware::CPU.is_64_bit?
    url 'https://github.com/ericchiang/pup/releases/download/v${VERSION}/${DARWIN_AMD64}'
    sha256 '$( sha256sum dist/${DARWIN_AMD64}  | awk '{ print $1 }' | xargs printf )'
  else
    url 'https://github.com/ericchiang/pup/releases/download/v${VERSION}/${DARWIN_386}'
    sha256 '$( sha256sum dist/${DARWIN_386}  | awk '{ print $1 }' | xargs printf )'
  end

  def install
    bin.install 'pup'
  end
end
EOF
