#!/usr/bin/env bash
# paketler dalındaki oturum-NN klasörünü zip olarak oturum-NN sürüm ekine yükler.
# make oturum N=NN komutu bu eki indirir.
set -euo pipefail
NO="${PAKET_NO:?paket numarası eksik}"
NO="$(printf '%02d' "$((10#${NO}))")"
git fetch --quiet --depth 1 origin paketler
gecici="$(mktemp -d)"
git archive FETCH_HEAD "oturum-${NO}" | tar -x -C "${gecici}"
( cd "${gecici}/oturum-${NO}" && zip -qr "${gecici}/oturum-${NO}.zip" . )
unzip -l "${gecici}/oturum-${NO}.zip" | tee "${SONUC_DIZIN}/paket-${NO}.txt"
if ! gh release view "oturum-${NO}" -R "${DEPO}" >/dev/null 2>&1; then
  gh release create "oturum-${NO}" -R "${DEPO}" --title "Oturum ${NO} başlangıç dosyaları" \
    --notes "make oturum N=${NO} komutu bu paketi indirir. Paket, depoda bulunan dosyaların üzerine yazmaz."
fi
gh release upload "oturum-${NO}" "${gecici}/oturum-${NO}.zip" -R "${DEPO}" --clobber
echo "oturum-${NO} paketi yayımlandı."
