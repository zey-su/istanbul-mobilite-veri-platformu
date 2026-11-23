#!/usr/bin/env bash
# "Lab" iş akışının tek giriş noktası. Etikete ya da elle seçilen işe göre
# veri hazırlama, imaj yayımlama ve ortam testini sırayla çalıştırır.
# Her çalışmanın özeti ve günlükleri ci-sonuc dalına yazılır.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
SONUC_DIZIN="$(mktemp -d)"
export SONUC_DIZIN

isler=()
case "${OLAY:-}" in
  workflow_dispatch)
    case "${IS:-test}" in
      veri) isler=(veri test) ;;
      imaj) isler=(imaj test) ;;
      teshis) isler=(teshis) ;;
      paket:*) isler=(paket); export PAKET_NO="${IS#paket:}" ;;
      *) isler=(test) ;;
    esac ;;
  push)
    if [ "${REF_TURU:-}" = "tag" ]; then
      case "${ETIKET:-}" in
        veri-v*) isler=(veri test) ;;
        imaj-v*) isler=(imaj test) ;;
        test-v*) isler=(test) ;;
      esac
    elif [ -n "${ONCEKI:-}" ] && [ "${ONCEKI}" != "0000000000000000000000000000000000000000" ] \
         && git diff --name-only "${ONCEKI}" HEAD -- | grep -qE '^(\.devcontainer/|lab/|Makefile$)'; then
      isler=(test)
    fi ;;
esac

if [ "${#isler[@]}" -eq 0 ]; then
  echo "Bu olay için çalışacak lab işi yok."
  exit 0
fi

durum=0
baslangic=$(date +%s)
for is in "${isler[@]}"; do
  echo "::group::${is}"
  is_baslangic=$(date +%s)
  if bash "lab/ci/${is}.sh" 2>&1 | tee "${SONUC_DIZIN}/${is}.log"; then
    sonuc="TAMAM"
  else
    sonuc="HATA"
    durum=1
  fi
  echo "${is} ${sonuc} $(( $(date +%s) - is_baslangic )) sn" >> "${SONUC_DIZIN}/isler.txt"
  echo "::endgroup::"
  [ "${durum}" -ne 0 ] && break
done
echo "toplam $(( $(date +%s) - baslangic )) sn" >> "${SONUC_DIZIN}/isler.txt"

bash lab/ci/sonuc_yaz.sh "${durum}" "${isler[*]}" || echo "Sonuç dalı yazılamadı."
exit "${durum}"
