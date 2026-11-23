"""Lab veri setlerini indirir ve sağlama toplamıyla doğrular.

Kullanım: make veri
Dosya listesi ve indirme adresleri lab/veri_listesi.json dosyasında durur. Doğrulanmış dosya yeniden indirilmez.
"""
import hashlib
import json
import os
import sys
import urllib.request
from pathlib import Path

LAB_KOK = Path(os.environ.get("LAB_KOK", Path(__file__).resolve().parents[1]))
VERI = LAB_KOK / "veri"


def ozet(yol):
    h = hashlib.sha256()
    with yol.open("rb") as akis:
        for parca in iter(lambda: akis.read(1 << 20), b""):
            h.update(parca)
    return h.hexdigest()


def indir(adres, hedef, boyut):
    gecici = hedef.with_suffix(hedef.suffix + ".indiriliyor")
    with urllib.request.urlopen(adres, timeout=60) as yanit, gecici.open("wb") as cikis:
        alinan = 0
        while True:
            parca = yanit.read(1 << 20)
            if not parca:
                break
            cikis.write(parca)
            alinan += len(parca)
            if boyut:
                print(f"\r  {hedef.name}: %{alinan * 100 // boyut}", end="", flush=True)
    print()
    gecici.replace(hedef)


def main():
    liste = json.loads((LAB_KOK / "lab" / "veri_listesi.json").read_text(encoding="utf-8"))
    VERI.mkdir(exist_ok=True)
    hatali = []
    for dosya in liste["dosyalar"]:
        hedef = VERI / dosya["ad"]
        if hedef.exists() and ozet(hedef) == dosya["sha256"]:
            print(f"Hazır: {dosya['ad']}")
            continue
        print(f"İndiriliyor: {dosya['ad']} ({dosya['boyut'] / 1024 / 1024:.0f} MB)")
        try:
            indir(f"{liste['taban_adres']}/{dosya['ad']}", hedef, dosya["boyut"])
        except Exception as hata:
            print(f"  İndirilemedi: {hata}")
            hatali.append(dosya["ad"])
            continue
        if ozet(hedef) != dosya["sha256"]:
            print("  Sağlama toplamı tutmadı; dosya silindi.")
            hedef.unlink()
            hatali.append(dosya["ad"])
    if hatali:
        print(f"\n{len(hatali)} dosya indirilemedi: {', '.join(hatali)}. Komut yeniden çalıştırıldığında yalnızca bu dosyalar indirilir.")
        sys.exit(1)
    print(f"\n{len(liste['dosyalar'])} dosya veri/ klasöründe hazır.")


if __name__ == "__main__":
    main()
