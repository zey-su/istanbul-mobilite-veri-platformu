#!/usr/bin/env bash
# Devcontainer'ı Codespaces'in kullandığı tanımla açar, veriyi indirir ve make kontrol adımlarını çalıştırır.
set -euo pipefail

if [ ! -f lab/veri_listesi.json ]; then
  echo "lab/veri_listesi.json henüz yok; ortam testi veri hazırlandıktan sonra çalışır. Bu çalışmada test atlandı."
  echo "test atlandı: veri listesi yok" >> "${SONUC_DIZIN}/sureler.txt"
  exit 0
fi

# Barındırılan çalıştırıcının diski 8,5 GB'lık imaj ve lab verisi için dardır; kullanılmayan araç zincirleri silinir.
# Codespaces'te bu adım çalışmaz.
if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
  sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL 2>/dev/null || true
  df -h / | tail -1
fi

npm install --silent -g @devcontainers/cli@0.90.0
echo "${GH_TOKEN}" | docker login ghcr.io -u "${SAHIP}" --password-stdin >/dev/null

# Özel depoda sürüm ekleri herkese açık adresten inmez; dosyalar gh ile önceden indirilir.
# make veri bu durumda yalnızca sağlama toplamlarını doğrular.
if [ "${GIZLI_DEPO:-}" = "true" ]; then
  surum="$(jq -r .surum lab/veri_listesi.json)"
  mkdir -p veri
  gh release download "${surum}" -R "${DEPO}" -D veri -p '*.csv.gz' --clobber
fi

olc() {
  local ad="$1"; shift
  local bas; bas=$(date +%s)
  "$@"
  echo "${ad}: $(( $(date +%s) - bas )) sn" >> "${SONUC_DIZIN}/sureler.txt"
}

olc "devcontainer up" devcontainer up --workspace-folder . > "${SONUC_DIZIN}/devcontainer-up.json"
olc "make veri" devcontainer exec --workspace-folder . make veri
olc "make kontrol" bash -c 'devcontainer exec --workspace-folder . make kontrol | tee "${SONUC_DIZIN}/kontrol.txt"; exit "${PIPESTATUS[0]}"'
devcontainer exec --workspace-folder . bash -c 'df -h / /workspaces 2>/dev/null; free -m; du -sh /opt/lab 2>/dev/null' > "${SONUC_DIZIN}/kaynak.txt" 2>&1 || true
