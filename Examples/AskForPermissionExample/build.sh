#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="AskForPermissionExample"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
LIB_OUT="build/lib"
PACKAGE_ROOT="$(cd ../.. && pwd)"
TARGET="arm64-apple-macos13"

rm -rf "${APP_DIR}" "${LIB_OUT}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources" "${LIB_OUT}"
cp Info.plist "${CONTENTS}/Info.plist"

LIBRARY_SOURCES=$(find "${PACKAGE_ROOT}/Sources/AskForPermission" -name '*.swift' | sort)
EXAMPLE_SOURCES=$(find Sources -name '*.swift' | sort)

# 1. Compile the library into a module + a single object file.
swiftc \
    -module-name AskForPermission \
    -target "${TARGET}" \
    -O -wmo \
    -emit-module \
    -emit-module-path "${LIB_OUT}/AskForPermission.swiftmodule" \
    -emit-object \
    -o "${LIB_OUT}/AskForPermission.o" \
    ${LIBRARY_SOURCES}

# 2. Compile the example, importing the library module and linking the object file.
swiftc \
    -target "${TARGET}" \
    -O \
    -I "${LIB_OUT}" \
    -o "${CONTENTS}/MacOS/${APP_NAME}" \
    "${LIB_OUT}/AskForPermission.o" \
    ${EXAMPLE_SOURCES}

codesign --force --deep --sign - "${APP_DIR}"

echo "Built ${APP_DIR}"
echo "Run: open ${APP_DIR}"
