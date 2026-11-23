"""Lab ortamını on iki adımda sınar.

Kullanım: make kontrol
Her adım TAMAM ya da HATA sonucu verir. Betik en altta TAMAM veren adımların sayısını 12/12 biçiminde yazar.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
from pathlib import Path

LAB_KOK = Path(os.environ.get("LAB_KOK", Path(__file__).resolve().parents[1]))
DURUM = LAB_KOK / ".lab"
BEKLENEN = {}
for satir in (LAB_KOK / "lab" / "surumler.env").read_text(encoding="utf-8").splitlines():
    if "=" in satir and not satir.startswith("#"):
        anahtar, deger = satir.split("=", 1)
        BEKLENEN[anahtar] = deger.strip()


def calistir(komut, zaman_asimi=120, ortam=None):
    sonuc = subprocess.run(komut, capture_output=True, text=True, timeout=zaman_asimi,
                           env={**os.environ, **(ortam or {})}, shell=isinstance(komut, str))
    return sonuc.returncode, (sonuc.stdout or "") + (sonuc.stderr or "")


def adim_python():
    surum = f"{sys.version_info.major}.{sys.version_info.minor}"
    return surum == BEKLENEN["PYTHON_SURUM"], f"{sys.version.split()[0]}"


def adim_java():
    kod, cikti = calistir(["java", "-version"])
    satir = next((s for s in cikti.splitlines() if "version" in s), cikti.strip()[:80])
    return kod == 0 and f'"{BEKLENEN["JAVA_SURUM"]}.' in satir, satir.strip()


def adim_duckdb():
    import duckdb
    kod, cikti = calistir(["duckdb", "-no-agent", "-csv", "-noheader", "-c", "SELECT version();"])
    cli = cikti.strip().splitlines()[-1] if cikti.strip() else "yok"
    beklenen = "v" + BEKLENEN["DUCKDB_SURUM"]
    return duckdb.__version__ == BEKLENEN["DUCKDB_SURUM"] and cli == beklenen, f"Python {duckdb.__version__}, komut satırı {cli}"


def adim_postgres():
    kod, cikti = calistir(["pg_isready", "-h", str(DURUM / "soket"), "-p", "5432"])
    return kod == 0, cikti.strip() or "yanıt yok"


def adim_polaris():
    import requests
    try:
        yanit = requests.get("http://127.0.0.1:8182/q/health/ready", timeout=10)
        return yanit.status_code == 200 and yanit.json().get("status") == "UP", f"sağlık durumu {yanit.json().get('status')}"
    except Exception as hata:
        return False, f"bağlantı kurulamadı ({type(hata).__name__}); make baslat ile servisler açılır"


def duckdb_baglan():
    import duckdb
    baglanti = duckdb.connect()
    baglanti.execute((DURUM / "baglan.sql").read_text(encoding="utf-8"))
    return baglanti


def adim_iceberg():
    baglanti = duckdb_baglan()
    baglanti.execute("CREATE SCHEMA IF NOT EXISTS lake.kontrol")
    baglanti.execute("DROP TABLE IF EXISTS lake.kontrol.deneme")
    baglanti.execute("CREATE TABLE lake.kontrol.deneme (hat VARCHAR, yolculuk BIGINT)")
    baglanti.execute("INSERT INTO lake.kontrol.deneme VALUES ('M2', 120), ('34', 80)")
    baglanti.execute("INSERT INTO lake.kontrol.deneme VALUES ('T1', 40)")
    satir = baglanti.execute("SELECT count(*), sum(yolculuk) FROM lake.kontrol.deneme").fetchall()[0]
    snapshot = baglanti.execute("SELECT count(*) FROM iceberg_snapshots('lake.kontrol.deneme')").fetchall()[0][0]
    return satir == (3, 240) and snapshot == 2, f"3 satır yazıldı ve okundu, {snapshot} snapshot oluştu"


def adim_spark():
    betik = textwrap.dedent("""
        from pyspark.sql import SparkSession
        spark = SparkSession.builder.appName("lab-kontrol").getOrCreate()
        spark.sparkContext.setLogLevel("ERROR")
        sonuc = spark.sql("SELECT count(*) AS adet, sum(yolculuk) AS toplam FROM lake.kontrol.deneme").collect()[0]
        print(f"SONUC {spark.version} {sonuc.adet} {sonuc.toplam}")
        spark.stop()
    """)
    baslangic = time.time()
    kod, cikti = calistir([sys.executable, "-c", betik], zaman_asimi=240,
                          ortam={"SPARK_CONF_DIR": str(DURUM / "spark")})
    satir = next((s for s in cikti.splitlines() if s.startswith("SONUC ")), "")
    parcalar = satir.split()
    tamam = kod == 0 and len(parcalar) == 4 and parcalar[1] == BEKLENEN["SPARK_SURUM"] and parcalar[2:] == ["3", "240"]
    sure = round(time.time() - baslangic)
    if tamam:
        return True, f"Spark {parcalar[1]} aynı tabloyu okudu ({sure} sn)"
    return False, (cikti.strip().splitlines() or ["çıktı yok"])[-1][:120]


def adim_kafka():
    from confluent_kafka import Consumer, Producer
    pid_dosyasi = DURUM / "kafka.pid"
    biz_baslattik = False
    if not pid_dosyasi.exists():
        kod, cikti = calistir(["bash", str(LAB_KOK / "lab" / "servis.sh"), "kafka-baslat"], zaman_asimi=120)
        if kod != 0:
            return False, cikti.strip().splitlines()[-1][:120]
        biz_baslattik = True
    try:
        uretici = Producer({"bootstrap.servers": "localhost:9092", "log_level": 0})
        for i in range(3):
            uretici.produce("lab-kontrol", key=f"durak-{i}", value=f"gecis-{i}")
        uretici.flush(15)
        tuketici = Consumer({"bootstrap.servers": "localhost:9092", "group.id": f"kontrol-{time.time_ns()}",
                             "auto.offset.reset": "earliest", "log_level": 0})
        tuketici.subscribe(["lab-kontrol"])
        alinan, baslangic = 0, time.time()
        while alinan < 3 and time.time() - baslangic < 30:
            mesaj = tuketici.poll(1.0)
            if mesaj is not None and not mesaj.error():
                alinan += 1
        tuketici.close()
        return alinan >= 3, f"3 olay üretildi, {alinan} olay tüketildi"
    finally:
        if biz_baslattik:
            calistir(["bash", str(LAB_KOK / "lab" / "servis.sh"), "kafka-durdur"], zaman_asimi=60)


def adim_airflow():
    gecici = Path(tempfile.mkdtemp(prefix="airflow-kontrol-", dir=DURUM))
    (gecici / "dags").mkdir()
    (gecici / "dags" / "lab_kontrol.py").write_text(textwrap.dedent("""
        from datetime import datetime
        from airflow.sdk import dag, task

        @dag(schedule=None, start_date=datetime(2026, 11, 1), catchup=False)
        def lab_kontrol():
            @task
            def selam():
                return "lab hazır"
            selam()

        lab_kontrol()
    """), encoding="utf-8")
    ortam = {"AIRFLOW_HOME": str(gecici), "AIRFLOW__CORE__DAGS_FOLDER": str(gecici / "dags"),
             "AIRFLOW__CORE__LOAD_EXAMPLES": "False"}
    try:
        kod, surum = calistir(["airflow", "version"], zaman_asimi=120, ortam=ortam)
        surum = surum.strip().splitlines()[-1] if surum.strip() else ""
        if surum != BEKLENEN["AIRFLOW_SURUM"]:
            return False, f"beklenen {BEKLENEN['AIRFLOW_SURUM']}, bulunan {surum or 'yok'}"
        calistir(["airflow", "db", "migrate"], zaman_asimi=180, ortam=ortam)
        kod, cikti = calistir(["airflow", "dags", "test", "lab_kontrol"], zaman_asimi=180, ortam=ortam)
        basarili = kod == 0 and "state=success" in cikti.replace(" ", "").lower().replace("dagrunstate.", "")
        if not basarili:
            basarili = kod == 0 and "success" in cikti.lower()
        return basarili, f"Airflow {surum}, örnek DAG çalıştı" if basarili else (cikti.strip().splitlines() or [""])[-1][:120]
    finally:
        shutil.rmtree(gecici, ignore_errors=True)


def adim_dbt():
    kod2, cikti2 = calistir(["dbt", "--version"])
    kod1, cikti1 = calistir(["dbt-core", "--version"])
    tamam = BEKLENEN["DBT_SURUM"] in cikti2 and BEKLENEN["DBT_CORE_SURUM"] in cikti1
    return tamam, f"dbt {BEKLENEN['DBT_SURUM']} ve dbt Core {BEKLENEN['DBT_CORE_SURUM']}" if tamam else "dbt sürümleri beklenenle uyuşmuyor"


def adim_veri():
    liste_dosyasi = LAB_KOK / "lab" / "veri_listesi.json"
    if not liste_dosyasi.exists():
        return False, "lab/veri_listesi.json bulunamadı"
    liste = json.loads(liste_dosyasi.read_text(encoding="utf-8"))
    eksik, bozuk = [], []
    for dosya in liste["dosyalar"]:
        yol = LAB_KOK / "veri" / dosya["ad"]
        if not yol.exists():
            eksik.append(dosya["ad"])
            continue
        ozet = hashlib.sha256()
        with yol.open("rb") as akis:
            for parca in iter(lambda: akis.read(1 << 20), b""):
                ozet.update(parca)
        if ozet.hexdigest() != dosya["sha256"]:
            bozuk.append(dosya["ad"])
    if eksik:
        return False, f"{len(eksik)} dosya eksik; make veri ile indirilir"
    if bozuk:
        return False, f"{len(bozuk)} dosyanın sağlama toplamı tutmadı; make veri ile yeniden indirilir"
    return True, f"{len(liste['dosyalar'])} dosya doğrulandı"


def adim_kaynak():
    bellek_kb = next(int(s.split()[1]) for s in Path("/proc/meminfo").read_text().splitlines() if s.startswith("MemTotal"))
    bellek_gb = bellek_kb / 1024 / 1024
    bos_gb = shutil.disk_usage(LAB_KOK).free / 1024 ** 3
    return bellek_gb >= 6.5 and bos_gb >= 5.0, f"bellek {bellek_gb:.1f} GB, boş disk {bos_gb:.0f} GB"


ADIMLAR = [
    ("Python", adim_python),
    ("Java", adim_java),
    ("DuckDB", adim_duckdb),
    ("PostgreSQL", adim_postgres),
    ("Polaris (REST katalog)", adim_polaris),
    ("Iceberg yazma ve okuma", adim_iceberg),
    ("Spark", adim_spark),
    ("Kafka", adim_kafka),
    ("Airflow", adim_airflow),
    ("dbt", adim_dbt),
    ("Veri dosyaları", adim_veri),
    ("Bellek ve disk", adim_kaynak),
]


def temizle():
    try:
        baglanti = duckdb_baglan()
        baglanti.execute("DROP TABLE IF EXISTS lake.kontrol.deneme")
        baglanti.execute("DROP SCHEMA IF EXISTS lake.kontrol")
    except Exception:
        pass


def main():
    print(f"Lab ortamı {len(ADIMLAR)} adımda sınanıyor.\n")
    sonuclar = []
    for sira, (ad, islev) in enumerate(ADIMLAR, 1):
        print(f"{sira:2d}. {ad} ...", end=" ", flush=True)
        try:
            tamam, ayrinti = islev()
        except Exception as hata:
            tamam, ayrinti = False, f"{type(hata).__name__}: {str(hata)[:110]}"
        sonuclar.append((ad, tamam, ayrinti))
        print("TAMAM" if tamam else "HATA", "|", ayrinti)
    temizle()

    print()
    genislik = max(len(ad) for ad, _, _ in sonuclar)
    for ad, tamam, ayrinti in sonuclar:
        print(f"  {ad:<{genislik}}  {'TAMAM' if tamam else 'HATA ':5}  {ayrinti}")
    print()
    tamam_sayisi = sum(1 for _, tamam, _ in sonuclar if tamam)
    if tamam_sayisi == len(sonuclar):
        print(f"Ortam hazır: {tamam_sayisi}/{len(sonuclar)} adım TAMAM.")
        sys.exit(0)
    hatalilar = [ad for ad, tamam, _ in sonuclar if not tamam]
    print(f"Ortam hazır değil: {tamam_sayisi}/{len(sonuclar)} adım TAMAM. Hatalı adımlar: {', '.join(hatalilar)}")
    print("Çözümler README.md dosyasının \"Sorun giderme\" bölümünde yer alır.")
    sys.exit(1)


if __name__ == "__main__":
    main()
