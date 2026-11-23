"""Polaris'te lab kataloğunu ve katman namespace'lerini oluşturur.

İlk kurulumda lab/servis.sh tarafından çalıştırılır. Komut ikinci kez çalıştığında var olan kataloğa dokunmaz.
"""
import os
import sys
from pathlib import Path

import requests

LAB_KOK = Path(os.environ.get("LAB_KOK", Path(__file__).resolve().parents[1]))
LAKEHOUSE = LAB_KOK / "lakehouse"
ADRES = "http://localhost:8181/api"
KATALOG = "lakehouse"
NAMESPACELER = ["bronze", "silver", "gold"]


def ortam():
    degerler = {}
    for satir in (LAB_KOK / ".lab" / "ortam.env").read_text(encoding="utf-8").splitlines():
        if "=" in satir and not satir.startswith("#"):
            anahtar, deger = satir.split("=", 1)
            degerler[anahtar.strip()] = deger.strip()
    return degerler


def jeton(istemci, gizli):
    yanit = requests.post(
        f"{ADRES}/catalog/v1/oauth/tokens",
        data={"grant_type": "client_credentials", "client_id": istemci,
              "client_secret": gizli, "scope": "PRINCIPAL_ROLE:ALL"},
        timeout=30,
    )
    yanit.raise_for_status()
    return yanit.json()["access_token"]


def main():
    o = ortam()
    basliklar = {"Authorization": f"Bearer {jeton(o['POLARIS_ISTEMCI'], o['POLARIS_GIZLI'])}"}
    konum = LAKEHOUSE.as_uri()

    var_olan = requests.get(f"{ADRES}/management/v1/catalogs", headers=basliklar, timeout=30)
    var_olan.raise_for_status()
    if KATALOG not in {k["name"] for k in var_olan.json().get("catalogs", [])}:
        govde = {"catalog": {
            "name": KATALOG,
            "type": "INTERNAL",
            "properties": {"default-base-location": konum},
            "storageConfigInfo": {"storageType": "FILE", "allowedLocations": [konum]},
        }}
        yanit = requests.post(f"{ADRES}/management/v1/catalogs", headers=basliklar, json=govde, timeout=30)
        yanit.raise_for_status()
        print(f"[lab] '{KATALOG}' kataloğu oluşturuldu: {konum}")

    for ad in NAMESPACELER:
        yanit = requests.post(f"{ADRES}/catalog/v1/{KATALOG}/namespaces", headers=basliklar,
                              json={"namespace": [ad], "properties": {}}, timeout=30)
        if yanit.status_code not in (200, 409):
            print(f"[lab] '{ad}' namespace'i oluşturulamadı: {yanit.status_code} {yanit.text[:200]}", file=sys.stderr)
            sys.exit(1)
    print(f"[lab] Namespace'ler hazır: {', '.join(NAMESPACELER)}")


if __name__ == "__main__":
    main()
