#!/usr/bin/env bash
# İBB verisini indirir ve hazırlar, sürüm eki olarak yayımlar, lab/veri_listesi.json dosyasını main dalına işler.
set -euo pipefail
source lab/ci/ortak.sh

case "${ETIKET:-}" in
  veri-v*) SURUM="${ETIKET}" ;;
  *) SURUM="veri-v1" ;;
esac
export VERI_SURUMU="${SURUM}" GITHUB_REPOSITORY="${DEPO}"

python3 -m pip install --quiet duckdb==2.0.0 numpy

# data.ibb.gov.tr GitHub çalıştırıcılarından gelen bağlantıyı kabul etmiyor. Portaldan elle indirilen dosyalar
# "ham-veri" sürüm ekine (csv, csv.gz ya da zip) ya da "ham-veri" dalına parçalar halinde konur; betik onları buradan okur.
GIRDI="$(pwd)/veri_ham_girdi"
mkdir -p "${GIRDI}"
if gh release view ham-veri -R "${DEPO}" >/dev/null 2>&1; then
  gh release download ham-veri -R "${DEPO}" -D "${GIRDI}" --clobber
fi
if git fetch --quiet --depth 1 origin ham-veri 2>/dev/null; then
  git --work-tree="${GIRDI}" checkout FETCH_HEAD -- . 2>/dev/null || true
  git reset --quiet
fi
for parca in "${GIRDI}"/*.parca-000; do
  [ -f "${parca}" ] || continue
  hedef="${parca%.parca-000}"
  cat "${hedef}".parca-* > "${hedef}" && rm -f "${hedef}".parca-*
done
for arsiv in "${GIRDI}"/*.zip; do
  [ -f "${arsiv}" ] || continue
  unzip -o -q "${arsiv}" -d "${GIRDI}" && rm -f "${arsiv}"
done
if find "${GIRDI}" -type f \( -iname '*.csv' -o -iname '*.csv.gz' \) | grep -q .; then
  export HAM_DIZIN="${GIRDI}"
  echo "Ham dosyalar ${GIRDI} klasöründen okunuyor:"
  find "${GIRDI}" -type f -printf '%f %s\n' | sort
fi
python3 lab/veri_hazirla.py
cp lab/veri_profili.json "${SONUC_DIZIN}/veri_profili.json"

NOT="Kaynak: İstanbul Büyükşehir Belediyesi Açık Veri Portalı (data.ibb.gov.tr). Lisans: İBB Açık Veri Lisansı. Dosyalar eğitim için yeniden düzenlenmiştir."
if gh release view "${SURUM}" -R "${DEPO}" >/dev/null 2>&1; then
  gh release upload "${SURUM}" veri_hazir/*.csv.gz -R "${DEPO}" --clobber
else
  gh release create "${SURUM}" veri_hazir/*.csv.gz -R "${DEPO}" --title "Lab verisi (${SURUM})" --notes "${NOT}"
fi
ls -l veri_hazir

main_dalina_isle "Veri listesi: ${SURUM}" lab/veri_listesi.json

# Aynı çalışmada test işi devcontainer imajını ve veriyi indirir; ara dosyalar disk açmak için silinir.
rm -rf "${GIRDI}" veri_ham veri_hazir
df -h . | tail -1
