#!/usr/bin/env bash
# Lab imajını derler, GitHub Container Registry'ye gönderir ve devcontainer.json dosyasını imajın özet değerine bağlar.
set -euo pipefail
source lab/ci/ortak.sh

SAHIP="${DEPO%%/*}"
IMAJ="ghcr.io/${SAHIP}/lab-ortami"
ETIKET_ADI="${ETIKET:-imaj-elle}"
case "${ETIKET_ADI}" in imaj-v*) ;; *) ETIKET_ADI="imaj-$(git rev-parse --short HEAD)" ;; esac

echo "${GH_TOKEN}" | docker login ghcr.io -u "${SAHIP}" --password-stdin >/dev/null
docker build -f .devcontainer/Dockerfile \
  --label "org.opencontainers.image.source=https://github.com/${DEPO}" \
  --label "org.opencontainers.image.description=İstanbul Mobilite Veri Platformu lab ortamı" \
  -t "${IMAJ}:${ETIKET_ADI}" .
docker push --quiet "${IMAJ}:${ETIKET_ADI}"
OZET="$(docker inspect --format '{{index .RepoDigests 0}}' "${IMAJ}:${ETIKET_ADI}")"
echo "Yayımlanan imaj: ${OZET}"
echo "${OZET}" > "${SONUC_DIZIN}/imaj.txt"
docker image ls "${IMAJ}" >> "${SONUC_DIZIN}/imaj.txt"

python3 - "${OZET}" <<'PY'
import json, sys
yol = ".devcontainer/devcontainer.json"
ayar = json.load(open(yol, encoding="utf-8"))
ayar.pop("build", None)
ayar.pop("image", None)
yeni = {"name": ayar.pop("name"), "image": sys.argv[1]}
yeni.update(ayar)
open(yol, "w", encoding="utf-8").write(json.dumps(yeni, ensure_ascii=False, indent=2) + "\n")
PY
# Test, imajı GHCR'dan çekerek katılımcının yolunu izlesin diye yerel kopya silinir.
docker image rm "${IMAJ}:${ETIKET_ADI}" >/dev/null
docker builder prune -af >/dev/null
main_dalina_isle "Lab imajı: ${ETIKET_ADI}" .devcontainer/devcontainer.json
