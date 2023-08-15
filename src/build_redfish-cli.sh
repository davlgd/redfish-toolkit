#!/bin/bash

OUT_DIR="bin"
FILE="redfish-cli/redfish-cli.go"

# This function compiles the Go file for the specified OS and architecture.
# The `-a` flag forces a rebuild, ensuring the most recent version is compiled.
# The `-ldflags="-s -w"` strips debug information, reducing the binary size.
compile() {
    local OS=$1
    local ARCH=$2
    local OUT_FILE="redfish-cli-$OS-$ARCH"
    [ "$OS" = "windows" ] && OUT_FILE="$OUT_FILE.exe"

    echo -ne "Compiling for $OS/$ARCH...\r"

    if GOOS=$OS GOARCH=$ARCH go build -a -ldflags="-s -w" -o $OUT_DIR/$OUT_FILE $FILE; then
        echo -ne "Compilation for $OS/$ARCH completed ✅"
    else
        echo -ne "Error during compilation for $OS/$ARCH ❌"
    fi
    echo
}

# Create the output directory if it doesn't exist
[ ! -d "$OUT_DIR" ] && mkdir "$OUT_DIR"

# Compile for every targeted OS & architecture
compile linux arm
compile linux amd64
compile darwin arm64
compile darwin amd64
compile windows amd64