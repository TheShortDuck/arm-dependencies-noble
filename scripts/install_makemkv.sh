#!/bin/bash

# Setup taken from https://github.com/tianon/dockerfiles/blob/master/makemkv/Dockerfile
# The Expat/MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

## ARM Modification of base script
# Define colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

# Auto-grab latest version
echo -e "${GREEN}Finding current MakeMKV version${NC}"

# Check if VERSION_MAKEMKV exists in the ARM source tree.
# The Docker build does not contain .git, so git rev-parse cannot
# be used here.
VERSION_FILE="/opt/arm/VERSION_MAKEMKV"

if [[ -f "$VERSION_FILE" ]]; then
    MAKEMKV_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
    echo -e "Using MakeMKV version from VERSION_MAKEMKV: ${GREEN}$MAKEMKV_VERSION${NC}"
else
    echo -e "${RED}ERROR:${NC} VERSION_MAKEMKV file not found at $VERSION_FILE"
    exit 1
fi
echo -e "${GREEN}Preparing MakeMKV $MAKEMKV_VERSION${NC}"
## Finish ARM Modification

set -ex
savedAptMark="$(apt-mark showmanual)"

# MakeMKV website is currently unavailable, so use the release
# tarballs supplied in the Docker build context.
OSS_TARBALL="/opt/arm/makemkv-oss-${MAKEMKV_VERSION}.tar.gz"
BIN_TARBALL="/opt/arm/makemkv-bin-${MAKEMKV_VERSION}.tar.gz"

echo -e "${GREEN}Using local MakeMKV release tarballs${NC}"

if [[ ! -f "$OSS_TARBALL" ]]; then
    echo -e "${RED}ERROR:${NC} $OSS_TARBALL not found"
    exit 1
fi

if [[ ! -f "$BIN_TARBALL" ]]; then
    echo -e "${RED}ERROR:${NC} $BIN_TARBALL not found"
    exit 1
fi

echo -e "${GREEN}Checking MakeMKV tarballs${NC}"
tar -tzf "$OSS_TARBALL" >/dev/null
tar -tzf "$BIN_TARBALL" >/dev/null

echo "OSS SHA256:"
sha256sum "$OSS_TARBALL"

echo "BIN SHA256:"
sha256sum "$BIN_TARBALL"


export PREFIX='/usr/local'
for ball in makemkv-oss makemkv-bin; do
	cp "/opt/arm/${ball}-${MAKEMKV_VERSION}.tar.gz" "$ball.tgz"
	mkdir -p "$ball"
	tar -xvf "$ball.tgz" -C "$ball" --strip-components=1
	rm "$ball.tgz"
	cd "$ball"
	if [ -f configure ]; then
		./configure --prefix="$PREFIX"
	else
		mkdir -p tmp
		touch tmp/eula_accepted
	fi
	make -j "$(nproc)" PREFIX="$PREFIX"
	make install PREFIX="$PREFIX"
	cd ..
	rm -r "$ball"
done

apt-mark auto '.*' > /dev/null
# shellcheck disable=SC2086
[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark # double quoting this var breaks the build
find /usr/local -type f -executable -exec ldd '{}' ';' \
	| awk '/=>/ { print $(NF-1) }' \
	| sort -u \
	| xargs -r dpkg-query --search \
	| cut -d: -f1 \
	| sort -u \
	| xargs -r apt-mark manual
