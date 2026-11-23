#!/usr/bin/env bash
# Çalışmanın özetini GitHub iş özeti sayfasına ve ci-sonuc dalındaki ayrı bir klasöre yazar.
# Günlüklerin yalnızca son satırları saklanır.
set -uo pipefail
durum="$1"; isler="$2"
klasor="kosu-${GITHUB_RUN_NUMBER:-0}-${isler// /-}"

{
  echo "# Lab çalışması ${GITHUB_RUN_NUMBER:-?}"
  echo
  echo "- İşler: ${isler}"
  echo "- Sonuç: $([ "${durum}" = 0 ] && echo TAMAM || echo HATA)"
  echo "- Olay: ${OLAY:-?} ${ETIKET:-}"
  echo "- Kayıt: $(git rev-parse --short HEAD) $(git log -1 --format=%s)"
  echo "- Zaman: $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo '```'
  cat "${SONUC_DIZIN}/isler.txt" 2>/dev/null
  cat "${SONUC_DIZIN}/sureler.txt" 2>/dev/null
  echo '```'
  if [ -f "${SONUC_DIZIN}/kontrol.txt" ]; then
    echo
    echo '```'
    tail -n 20 "${SONUC_DIZIN}/kontrol.txt"
    echo '```'
  fi
} > "${SONUC_DIZIN}/ozet.md"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "${SONUC_DIZIN}/ozet.md" >> "${GITHUB_STEP_SUMMARY}"

for gunluk in "${SONUC_DIZIN}"/*.log; do
  [ -f "${gunluk}" ] || continue
  tail -n 400 "${gunluk}" > "${gunluk}.son" && mv "${gunluk}.son" "${gunluk}"
done

agac="$(mktemp -d)"
if git fetch --quiet origin ci-sonuc 2>/dev/null; then
  git worktree add --quiet "${agac}" FETCH_HEAD
  cd "${agac}" && git checkout --quiet -B ci-sonuc
else
  git worktree add --quiet --detach "${agac}"
  cd "${agac}" && git checkout --quiet --orphan ci-sonuc && git rm -rq . 2>/dev/null
  printf '# CI sonuçları\n\nBu dal yalnızca lab iş akışının çıktılarını taşır.\n' > README.md
fi
mkdir -p "${klasor}"
cp -r "${SONUC_DIZIN}"/. "${klasor}/"
git add -A
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "CI sonucu: ${klasor}"
git push --quiet origin ci-sonuc
