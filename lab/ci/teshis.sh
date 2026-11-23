#!/usr/bin/env bash
# Ağ teşhisi: İBB Açık Veri Portalı'na GitHub çalıştırıcısından erişimi sınar.
set -uo pipefail
for alan in data.ibb.gov.tr ibb.istanbul www.turkiye.gov.tr github.com; do
  echo "== ${alan}"
  getent ahosts "${alan}" | awk '{print $1}' | sort -u | head -4
  curl -4 -sS -o /dev/null --max-time 25 -w "ipv4 http=%{http_code} baglanti=%{time_connect}s toplam=%{time_total}s\n" "https://${alan}/" 2>&1 | tail -1
done
echo "== CKAN API"
curl -4 -sS --max-time 40 "https://data.ibb.gov.tr/api/3/action/package_show?id=hourly-traffic-density-data-set" -o /tmp/p.json -w "http=%{http_code} toplam=%{time_total}s\n" 2>&1 | tail -1
head -c 300 /tmp/p.json 2>/dev/null; echo
curl -sS --max-time 10 https://ipinfo.io/json 2>/dev/null | grep -E '"(country|region|org)"' || true
echo "== GitHub meta: Codespaces alan adları"
curl -sS --max-time 20 https://api.github.com/meta | jq -c '.domains.codespaces' 2>&1 | head -5
