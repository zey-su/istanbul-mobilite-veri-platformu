"""Oturum paketlerini indirir ve oturumlar arası görev kontrollerini çalıştırır.

Kullanım:
  make oturum N=01         Oturum 1'in başlangıç dosyalarını depoya ekler
  make odev-kontrol N=01   Oturum 1'den sonraki görevi sınar ve kanıt kodunu yazar

Paketler şablon deponun paketler dalında ve sürüm eklerinde durur. Paket, depoda zaten bulunan bir dosyanın
üzerine yazmaz; böylece katılımcının kendi çalışması korunur.
"""
import io
import os
import runpy
import sys
import urllib.request
import zipfile
from pathlib import Path

SABLON = "veri-muhendisligi-bootcamp/istanbul-mobilite-veri-platformu"
LAB_KOK = Path(os.environ.get("LAB_KOK", Path(__file__).resolve().parents[1]))


def numara(deger):
    if not deger or not deger.strip().isdigit():
        print("Oturum numarası eksik. Örnek: make oturum N=01")
        sys.exit(2)
    return f"{int(deger):02d}"


def oturum(no):
    adresler = [f"https://github.com/{SABLON}/raw/paketler/oturum-{no}.zip",
                f"https://github.com/{SABLON}/releases/download/oturum-{no}/oturum-{no}.zip"]
    veri, hata = None, None
    for adres in adresler:
        print(f"Oturum {int(no)} paketi indiriliyor: {adres}")
        try:
            with urllib.request.urlopen(adres, timeout=60) as yanit:
                veri = yanit.read()
            break
        except Exception as son_hata:
            hata = son_hata
    if veri is None:
        print(f"Paket indirilemedi ({hata}). Paket oturum günü yayımlanır; yayımlandıysa komut yeniden çalıştırılır.")
        sys.exit(1)
    eklenen, korunan = [], []
    with zipfile.ZipFile(io.BytesIO(veri)) as arsiv:
        for oge in arsiv.infolist():
            if oge.is_dir():
                continue
            hedef = (LAB_KOK / oge.filename).resolve()
            if LAB_KOK.resolve() not in hedef.parents:
                continue
            if hedef.exists():
                korunan.append(oge.filename)
                continue
            hedef.parent.mkdir(parents=True, exist_ok=True)
            hedef.write_bytes(arsiv.read(oge))
            eklenen.append(oge.filename)
    for ad in sorted(eklenen):
        print(f"  eklendi: {ad}")
    for ad in sorted(korunan):
        print(f"  zaten var, dokunulmadı: {ad}")
    print(f"Oturum {int(no)} dosyaları hazır.")
    print(f"Görevleri oturumlar/{no}/OKU-BENI.md dosyası anlatır.")


def odev_kontrol(no):
    betik = LAB_KOK / "lab" / "odev" / f"kontrol_{no}.py"
    if not betik.exists():
        print(f"{betik.relative_to(LAB_KOK)} bulunamadı. Önce make oturum N={no} çalıştırılır.")
        sys.exit(1)
    runpy.run_path(str(betik), run_name="__main__")


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("oturum", "odev-kontrol"):
        print(__doc__)
        sys.exit(2)
    (oturum if sys.argv[1] == "oturum" else odev_kontrol)(numara(sys.argv[2]))
