#!/bin/bash
#
# Genera iOSNetworkContract.xcframework (iOS device + simulator) desde el Swift Package.
#
# Maneja el gotcha de SwiftPM → XCFramework: el `xcodebuild archive` de un
# Swift Package deja el .framework en usr/local/lib SIN el directorio Modules/
# (swiftmodule + swiftinterface). Este script los copia manualmente para que
# los consumidores puedan hacer `import iOSNetworkContract`.
#
# Uso:
#   ./scripts/build-xcframework.sh
#
# Output:
#   build/iOSNetworkContract.xcframework        — el framework binario
#   build/iOSNetworkContract.xcframework.zip    — comprimido para distribuir
#   build/checksum.txt                        — sha256 para Package.swift (.binaryTarget)
#
set -euo pipefail

SCHEME="iOSNetworkContract"
BUILD_DIR="build"
OUTPUT="${BUILD_DIR}/${SCHEME}.xcframework"
ZIP="${BUILD_DIR}/${SCHEME}.xcframework.zip"

# Correr desde la raíz del repo (donde está Package.swift).
cd "$(dirname "$0")/.."

echo "==> Limpiando build anterior"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

COMMON_FLAGS="SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES"

# archive_platform <nombre> <destination> <release-subdir>
# Archiva, ubica el .framework y le inyecta el Modules/ con el swiftmodule.
archive_platform() {
  local name="$1"
  local destination="$2"
  local release_subdir="$3"

  local archive="${BUILD_DIR}/${name}.xcarchive"
  local dd="${BUILD_DIR}/dd-${name}"

  echo "==> Archivando ${name} (${destination})"
  xcodebuild archive \
    -scheme "${SCHEME}" \
    -destination "${destination}" \
    -archivePath "${archive}" \
    -derivedDataPath "${dd}" \
    ${COMMON_FLAGS} \
    >/dev/null

  # El .framework puede estar en usr/local/lib (SwiftPM) o Library/Frameworks.
  local framework
  framework="$(find "${archive}/Products" -name "${SCHEME}.framework" -type d | head -1)"
  if [[ -z "${framework}" ]]; then
    echo "ERROR: no se encontró ${SCHEME}.framework en ${archive}"
    exit 1
  fi

  # El swiftmodule se genera en BuildProductsPath pero no se copia al framework.
  local swiftmodule
  swiftmodule="$(find "${dd}" -path "*${release_subdir}/${SCHEME}.swiftmodule" -type d | head -1)"
  if [[ -z "${swiftmodule}" ]]; then
    echo "ERROR: no se encontró ${SCHEME}.swiftmodule para ${name}"
    exit 1
  fi

  echo "    framework:   ${framework}"
  echo "    swiftmodule: ${swiftmodule}"

  # Inyectar Modules/iOSNetworkContract.swiftmodule/ dentro del framework.
  mkdir -p "${framework}/Modules/${SCHEME}.swiftmodule"
  cp -R "${swiftmodule}/." "${framework}/Modules/${SCHEME}.swiftmodule/"

  # Devolver el path del framework por stdout (última línea).
  echo "${framework}"
}

FW_IOS="$(archive_platform "ios" "generic/platform=iOS" "Release-iphoneos" | tail -1)"
FW_SIM="$(archive_platform "iossimulator" "generic/platform=iOS Simulator" "Release-iphonesimulator" | tail -1)"

echo "==> Combinando en XCFramework"
xcodebuild -create-xcframework \
  -framework "${FW_IOS}" \
  -framework "${FW_SIM}" \
  -output "${OUTPUT}" \
  >/dev/null

echo "==> Comprimiendo"
( cd "${BUILD_DIR}" && zip -r -q "$(basename "${ZIP}")" "$(basename "${OUTPUT}")" )

echo "==> Calculando checksum"
CHECKSUM="$(swift package compute-checksum "${ZIP}")"
echo "${CHECKSUM}" > "${BUILD_DIR}/checksum.txt"

echo ""
echo "✅ XCFramework generado:"
echo "   ${OUTPUT}"
echo "   ${ZIP}"
echo "   checksum: ${CHECKSUM}"
