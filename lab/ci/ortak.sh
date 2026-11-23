#!/usr/bin/env bash
# lab/ci betiklerinin ortak işlevleri.

bot_kimligi() {
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
}

# Verilen dosyaları main dalının en son haline işler ve gönderir.
# Çalışma ağacı bir etiket üzerinde olsa da dosyalar main dalına gider.
main_dalina_isle() {
  local mesaj="$1"; shift
  local gecici
  gecici="$(mktemp -d)"
  for dosya in "$@"; do
    mkdir -p "${gecici}/$(dirname "${dosya}")"
    cp "${dosya}" "${gecici}/${dosya}"
  done
  bot_kimligi
  git fetch --quiet origin main
  git checkout --quiet --force -B main origin/main
  for dosya in "$@"; do
    mkdir -p "$(dirname "${dosya}")"
    cp "${gecici}/${dosya}" "${dosya}"
    git add "${dosya}"
  done
  if git diff --cached --quiet; then
    echo "main dalında değişiklik yok."
  else
    git commit --quiet -m "${mesaj}"
    git push --quiet origin main
    echo "main dalına işlendi: ${mesaj}"
  fi
}
