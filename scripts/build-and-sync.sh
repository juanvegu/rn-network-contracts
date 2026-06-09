#!/bin/bash
#
# Loop de desarrollo local: construye el xcframework y lo sincroniza a los
# consumidores que lo referencian por path (sin pipeline ni Artifactory).
#
#   - @scotia/rn-network: recibe una copia en ios/iOSNetworkContract.xcframework
#     (la usa el podspec vía vendored_frameworks).
#   - App nativa: referenciá build/iOSNetworkContract.xcframework por path local
#     (Xcode → Add Local Package, o .binaryTarget(path:)).
#
# Uso (desde rn-network-contracts/):
#   ./scripts/build-and-sync.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

# Path al repo del módulo Expo, relativo a contracts. Ajustar si cambia el layout.
RN_NETWORK_IOS="../rn-network/ios"

echo "==> 1/2 Construyendo xcframework"
./scripts/build-xcframework.sh

echo ""
echo "==> 2/2 Sincronizando a @scotia/rn-network"
if [[ -d "${RN_NETWORK_IOS}" ]]; then
  rm -rf "${RN_NETWORK_IOS}/iOSNetworkContract.xcframework"
  cp -R build/iOSNetworkContract.xcframework "${RN_NETWORK_IOS}/"
  echo "    copiado → ${RN_NETWORK_IOS}/iOSNetworkContract.xcframework"
else
  echo "    ⚠️  No se encontró ${RN_NETWORK_IOS} — omito el sync al módulo Expo."
fi

echo ""
echo "✅ Listo."
echo "   App nativa (SPM): referenciá $(pwd)/build/iOSNetworkContract.xcframework"
echo "   @scotia/rn-network: ya tiene la copia fresca para el podspec vendored."
