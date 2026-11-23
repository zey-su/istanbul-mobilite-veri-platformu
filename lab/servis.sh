#!/usr/bin/env bash
# Lab servislerini kurar, başlatır, durdurur ve durumlarını gösterir.
# Kullanım: bash lab/servis.sh <komut>
#   ilk-kurulum     PostgreSQL kümesini, Polaris kataloğunu ve bağlantı dosyalarını hazırlar (bir kez çalışır)
#   baslat          Bağlantı dosyalarını yeniden yazar, PostgreSQL ve Polaris'i başlatır
#   durdur          Çalışan bütün lab servislerini durdurur
#   durum           Servislerin durumunu gösterir
#   kafka-baslat    Kafka'yı (KRaft, tek düğüm) başlatır
#   kafka-durdur    Kafka'yı durdurur
set -euo pipefail

LAB_KOK="${LAB_KOK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DURUM="${LAB_KOK}/.lab"
LOG="${DURUM}/log"
PG_VERI="${DURUM}/postgres"
PG_SOKET="${DURUM}/soket"
LAKEHOUSE="${LAB_KOK}/lakehouse"
POLARIS_EV="/opt/lab/polaris"
KAFKA_EV="/opt/lab/kafka"
export PATH="/usr/lib/postgresql/17/bin:/opt/lab/venv/bin:/opt/lab/kafka/bin:${PATH}"

bilgi() { printf '\033[1;34m[lab]\033[0m %s\n' "$*"; }
hata() { printf '\033[1;31m[lab]\033[0m %s\n' "$*" >&2; }

ortam_yukle() {
    if [ -f "${DURUM}/ortam.env" ]; then
        set -a
        # shellcheck disable=SC1091
        . "${DURUM}/ortam.env"
        set +a
    fi
}

rastgele() { python3 -c "import secrets; print(secrets.token_hex(16))"; }

# --- PostgreSQL -------------------------------------------------------------

postgres_calisiyor() { pg_ctl -D "${PG_VERI}" status >/dev/null 2>&1; }

postgres_baslat() {
    if postgres_calisiyor; then
        return 0
    fi
    rm -f "${PG_VERI}/postmaster.pid"
    pg_ctl -D "${PG_VERI}" -l "${LOG}/postgres.log" -w -t 60 \
        -o "-k ${PG_SOKET} -c listen_addresses=localhost -c port=5432" start >/dev/null
    bilgi "PostgreSQL çalışıyor (localhost:5432)."
}

postgres_durdur() {
    if postgres_calisiyor; then
        pg_ctl -D "${PG_VERI}" -m fast -w stop >/dev/null
        bilgi "PostgreSQL durdu."
    fi
}

psql_yonetici() { psql -h "${PG_SOKET}" -p 5432 -d postgres -v ON_ERROR_STOP=1 -q "$@"; }

# --- Polaris ----------------------------------------------------------------

polaris_saglikli() { curl -fs -o /dev/null http://127.0.0.1:8182/q/health/ready 2>/dev/null; }

polaris_ayar_yaz() {
    cat > "${DURUM}/polaris.properties" <<EOF
polaris.persistence.type=relational-jdbc
quarkus.datasource.db-kind=postgresql
quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/polaris
quarkus.datasource.username=polaris
quarkus.datasource.password=${PG_POLARIS_SIFRE}
quarkus.http.host=127.0.0.1
quarkus.management.host=127.0.0.1
polaris.features."SUPPORTED_CATALOG_STORAGE_TYPES"=["FILE"]
polaris.features."ALLOW_INSECURE_STORAGE_TYPES"=true
polaris.readiness.ignore-severe-issues=true
quarkus.log.file.enabled=false
quarkus.log.console.level=INFO
quarkus.http.access-log.enabled=false
EOF
    chmod 600 "${DURUM}/polaris.properties"
}

polaris_secenekleri() {
    printf '%s' "-Xms128m -Xmx512m -Dquarkus.config.locations=file:${DURUM}/polaris.properties"
}

polaris_baslat() {
    if polaris_saglikli; then
        return 0
    fi
    POLARIS_JAVA_OPTS="$(polaris_secenekleri)" nohup "${POLARIS_EV}/bin/server" > "${LOG}/polaris.log" 2>&1 &
    echo $! > "${DURUM}/polaris.pid"
    for _ in $(seq 1 90); do
        if polaris_saglikli; then
            bilgi "Polaris çalışıyor (http://localhost:8181)."
            return 0
        fi
        sleep 1
    done
    hata "Polaris 90 saniyede açılmadı. Ayrıntı: ${LOG}/polaris.log"
    return 1
}

polaris_durdur() {
    if [ -f "${DURUM}/polaris.pid" ] && kill -0 "$(cat "${DURUM}/polaris.pid")" 2>/dev/null; then
        kill "$(cat "${DURUM}/polaris.pid")"
        for _ in $(seq 1 30); do
            kill -0 "$(cat "${DURUM}/polaris.pid")" 2>/dev/null || break
            sleep 1
        done
        bilgi "Polaris durdu."
    fi
    rm -f "${DURUM}/polaris.pid"
}

# --- Kafka ------------------------------------------------------------------

kafka_calisiyor() {
    [ -f "${DURUM}/kafka.pid" ] && kill -0 "$(cat "${DURUM}/kafka.pid")" 2>/dev/null
}

kafka_baslat() {
    if kafka_calisiyor; then
        bilgi "Kafka zaten çalışıyor (localhost:9092)."
        return 0
    fi
    mkdir -p "${DURUM}/kafka-veri" "${LOG}/kafka"
    if [ ! -f "${DURUM}/kafka.properties" ]; then
        sed -e "s|^log.dirs=.*|log.dirs=${DURUM}/kafka-veri|" \
            -e "s|^listeners=.*|listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093|" \
            -e "s|^advertised.listeners=.*|advertised.listeners=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093|" \
            "${KAFKA_EV}/config/server.properties" > "${DURUM}/kafka.properties"
    fi
    if [ ! -f "${DURUM}/kafka-veri/meta.properties" ]; then
        KAFKA_KUME_KIMLIGI="$("${KAFKA_EV}/bin/kafka-storage.sh" random-uuid)"
        "${KAFKA_EV}/bin/kafka-storage.sh" format --standalone -t "${KAFKA_KUME_KIMLIGI}" \
            -c "${DURUM}/kafka.properties" > "${LOG}/kafka/format.log" 2>&1
    fi
    LOG_DIR="${LOG}/kafka" KAFKA_HEAP_OPTS="-Xms256m -Xmx512m" \
        nohup "${KAFKA_EV}/bin/kafka-server-start.sh" "${DURUM}/kafka.properties" > "${LOG}/kafka/sunucu.log" 2>&1 &
    echo $! > "${DURUM}/kafka.pid"
    for _ in $(seq 1 60); do
        if "${KAFKA_EV}/bin/kafka-topics.sh" --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
            bilgi "Kafka çalışıyor (localhost:9092)."
            return 0
        fi
        sleep 1
    done
    hata "Kafka 60 saniyede açılmadı. Ayrıntı: ${LOG}/kafka/sunucu.log"
    return 1
}

kafka_durdur() {
    if kafka_calisiyor; then
        kill "$(cat "${DURUM}/kafka.pid")"
        for _ in $(seq 1 30); do
            kill -0 "$(cat "${DURUM}/kafka.pid")" 2>/dev/null || break
            sleep 1
        done
        bilgi "Kafka durdu."
    fi
    rm -f "${DURUM}/kafka.pid"
}

# --- Kurulum ve bağlantı dosyaları -----------------------------------------

baglanti_dosyalari_yaz() {
    cat > "${DURUM}/baglan.sql" <<EOF
-- Lab bağlantısı: DuckDB'yi Polaris kataloğuna bağlar. Bu dosya Codespace her başladığında yeniden yazılır ve depoya girmez.
SET autoinstall_known_extensions = false;
-- Bellek sınırı: sınırı aşan sorgu diske taşar. Sınır olmadan büyük bir GROUP BY ya da DISTINCT Codespace belleğini doldurur.
SET memory_limit = '2GB';
LOAD httpfs;
LOAD iceberg;
CREATE OR REPLACE SECRET polaris_gizli (
    TYPE iceberg,
    CLIENT_ID '${POLARIS_ISTEMCI}',
    CLIENT_SECRET '${POLARIS_GIZLI}',
    OAUTH2_SERVER_URI 'http://localhost:8181/api/catalog/v1/oauth/tokens',
    OAUTH2_SCOPE 'PRINCIPAL_ROLE:ALL'
);
ATTACH OR REPLACE 'lakehouse' AS lake (
    TYPE iceberg,
    SECRET polaris_gizli,
    URI 'http://localhost:8181/api/catalog',
    ACCESS_DELEGATION_MODE 'none',
    STAGE_CREATE_TABLES false
);
EOF
    mkdir -p "${DURUM}/spark"
    cat > "${DURUM}/spark/spark-defaults.conf" <<EOF
spark.master                                   local[2]
spark.driver.memory                            1g
spark.ui.showConsoleProgress                   false
spark.jars                                     /opt/lab/jars/iceberg-spark-runtime-4.1_2.13-1.12.0.jar
spark.sql.extensions                           org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions
spark.sql.catalog.lake                         org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.lake.type                    rest
spark.sql.catalog.lake.uri                     http://localhost:8181/api/catalog
spark.sql.catalog.lake.warehouse               lakehouse
spark.sql.catalog.lake.credential              ${POLARIS_ISTEMCI}:${POLARIS_GIZLI}
spark.sql.catalog.lake.scope                   PRINCIPAL_ROLE:ALL
spark.sql.defaultCatalog                       lake
EOF
    chmod 600 "${DURUM}/baglan.sql" "${DURUM}/spark/spark-defaults.conf"
}

ilk_kurulum() {
    mkdir -p "${DURUM}" "${LOG}" "${PG_SOKET}" "${LAKEHOUSE}"
    chmod 700 "${DURUM}"
    if [ ! -f "${DURUM}/ortam.env" ]; then
        umask 077
        cat > "${DURUM}/ortam.env" <<EOF
# Lab kimlik bilgileri. İlk kurulumda rastgele üretilir ve depoya girmez.
PG_POLARIS_SIFRE=$(rastgele)
POLARIS_ISTEMCI=root
POLARIS_GIZLI=$(rastgele)
EOF
        umask 022
    fi
    ortam_yukle

    if [ ! -f "${PG_VERI}/PG_VERSION" ]; then
        bilgi "PostgreSQL kümesi oluşturuluyor."
        initdb -D "${PG_VERI}" --auth-local=trust --auth-host=scram-sha-256 \
            -E UTF8 --locale=C.UTF-8 > "${LOG}/initdb.log" 2>&1
    fi
    postgres_baslat
    if ! psql_yonetici -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'polaris'" | grep -q 1; then
        psql_yonetici -c "CREATE ROLE polaris LOGIN PASSWORD '${PG_POLARIS_SIFRE}';"
        psql_yonetici -c "CREATE DATABASE polaris OWNER polaris;"
        psql -h "${PG_SOKET}" -p 5432 -d polaris -v ON_ERROR_STOP=1 -q \
            -c "CREATE SCHEMA IF NOT EXISTS polaris_schema AUTHORIZATION polaris;"
    fi

    polaris_ayar_yaz
    if [ ! -f "${DURUM}/polaris-bootstrap.tamam" ]; then
        bilgi "Polaris kataloğu hazırlanıyor."
        POLARIS_JAVA_OPTS="$(polaris_secenekleri)" "${POLARIS_EV}/bin/admin" bootstrap \
            -r POLARIS -c "POLARIS,${POLARIS_ISTEMCI},${POLARIS_GIZLI}" > "${LOG}/polaris-bootstrap.log" 2>&1 \
            || { hata "Polaris hazırlanamadı. Ayrıntı: ${LOG}/polaris-bootstrap.log"; return 1; }
        touch "${DURUM}/polaris-bootstrap.tamam"
    fi
    polaris_baslat
    python3 "${LAB_KOK}/lab/katalog_kur.py"
    baglanti_dosyalari_yaz
    bilgi "İlk kurulum tamamlandı."
}

baslat() {
    if [ ! -f "${DURUM}/ortam.env" ]; then
        ilk_kurulum
        return
    fi
    ortam_yukle
    baglanti_dosyalari_yaz
    postgres_baslat
    polaris_baslat
}

durdur() {
    kafka_durdur
    polaris_durdur
    postgres_durdur
}

durum() {
    if postgres_calisiyor; then echo "PostgreSQL : çalışıyor"; else echo "PostgreSQL : kapalı"; fi
    if polaris_saglikli; then echo "Polaris    : çalışıyor"; else echo "Polaris    : kapalı"; fi
    if kafka_calisiyor; then echo "Kafka      : çalışıyor"; else echo "Kafka      : kapalı"; fi
}

case "${1:-}" in
    ilk-kurulum) ilk_kurulum ;;
    baslat) baslat ;;
    durdur) durdur ;;
    durum) durum ;;
    kafka-baslat) ortam_yukle; kafka_baslat ;;
    kafka-durdur) kafka_durdur ;;
    *) echo "Kullanım: bash lab/servis.sh {ilk-kurulum|baslat|durdur|durum|kafka-baslat|kafka-durdur}" >&2; exit 2 ;;
esac
