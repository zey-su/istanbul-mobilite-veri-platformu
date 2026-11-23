# İstanbul Mobilite Veri Platformu | lab komutları
# Her hedef, lab klasöründeki betiklerden birini çalıştırır.
SHELL := /bin/bash
LAB_KOK := $(CURDIR)
export LAB_KOK
export SPARK_CONF_DIR := $(LAB_KOK)/.lab/spark
# Giriş kabuğu PATH'i değiştirse de lab Python'u kullanılır.
LAB_PY := $(firstword $(wildcard /opt/lab/venv/bin/python) python3)
LAB_PYSPARK := $(firstword $(wildcard /opt/lab/venv/bin/pyspark) pyspark)

.PHONY: yardim ilk-kurulum baslat durdur durum sql spark kafka-baslat kafka-durdur veri kontrol oturum odev-kontrol

yardim:
	@echo "make baslat            PostgreSQL ve Polaris'i başlatır"
	@echo "make durdur            Çalışan lab servislerini durdurur"
	@echo "make durum             Servislerin durumunu gösterir"
	@echo "make sql               DuckDB'yi lab kataloğuna bağlı olarak açar"
	@echo "make spark             PySpark kabuğunu lab kataloğuna bağlı olarak açar"
	@echo "make kafka-baslat      Kafka'yı başlatır"
	@echo "make kafka-durdur      Kafka'yı durdurur"
	@echo "make veri              Lab veri setlerini indirir ve doğrular"
	@echo "make kontrol           Ortamı on iki adımda sınar"
	@echo "make oturum N=01       Oturumun başlangıç dosyalarını depoya ekler"
	@echo "make odev-kontrol N=01 Oturumdan sonraki görevi sınar ve kanıt kodunu yazar"

ilk-kurulum:
	@bash lab/servis.sh ilk-kurulum

baslat:
	@bash lab/servis.sh baslat

durdur:
	@bash lab/servis.sh durdur

durum:
	@bash lab/servis.sh durum

sql: baslat
	@duckdb -no-agent -init .lab/baglan.sql .lab/calisma.duckdb

spark: baslat
	@$(LAB_PYSPARK)

kafka-baslat:
	@bash lab/servis.sh kafka-baslat

kafka-durdur:
	@bash lab/servis.sh kafka-durdur

veri:
	@$(LAB_PY) lab/veri_indir.py

kontrol:
	@$(LAB_PY) lab/kontrol.py

oturum:
	@$(LAB_PY) lab/paket.py oturum $(N)

odev-kontrol:
	@$(LAB_PY) lab/paket.py odev-kontrol $(N)
