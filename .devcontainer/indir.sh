#!/usr/bin/env bash
# Bir dosyayı önce birincil, olmazsa yedek adresten indirir ve sağlama toplamını doğrular.
# Kullanım: indir.sh <hedef dosya> <sha256|sha512> <özet> <birincil adres> [yedek adres]
set -euo pipefail

hedef="$1"
algoritma="$2"
ozet="$3"
birincil="$4"
yedek="${5:-}"

indir_ve_dogrula() {
    local adres="$1"
    echo "İndiriliyor: ${adres}"
    curl -fsSL --retry 5 --retry-delay 3 --connect-timeout 20 -o "${hedef}" "${adres}" || return 1
    echo "${ozet}  ${hedef}" | "${algoritma}sum" -c - >/dev/null 2>&1 || {
        echo "Sağlama toplamı tutmadı: ${adres}" >&2
        return 1
    }
}

if indir_ve_dogrula "${birincil}"; then
    exit 0
fi
if [ -n "${yedek}" ] && indir_ve_dogrula "${yedek}"; then
    exit 0
fi
echo "İndirilemedi: ${hedef}" >&2
exit 1
