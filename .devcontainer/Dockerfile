# İstanbul Mobilite Veri Platformu | lab ortamı
# Sürümler lab/surumler.env dosyasıyla aynı tutulur. Her indirme sağlama toplamıyla doğrulanır.
ARG TEMEL_IMAJ=mcr.microsoft.com/devcontainers/python:2-3.13-trixie@sha256:c5c4c77e2919476f2e25998c4d9f73f489f3834197778132975f31a991623746
FROM ${TEMEL_IMAJ}

ARG DUCKDB_SURUM=2.0.0
ARG POLARIS_SURUM=1.9.0
ARG ICEBERG_SURUM=1.12.0
ARG KAFKA_SURUM=4.4.0
ARG UV_SURUM=0.11.32

ENV LAB_OPT=/opt/lab \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    PYTHONDONTWRITEBYTECODE=1
ENV PATH=/opt/lab/venv/bin:/opt/lab/kafka/bin:/usr/lib/postgresql/17/bin:${PATH}

USER root

# Java 21, PostgreSQL 17 ve yardımcı araçlar
# Temel imajdaki Yarn deposu imza anahtarı sorunu nedeniyle apt-get update adımını bozuyor; lab Yarn kullanmıyor.
RUN rm -f /etc/apt/sources.list.d/yarn* \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-21-jdk-headless postgresql-17 postgresql-client-17 jq unzip make \
 && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/indir.sh /usr/local/bin/lab-indir
RUN chmod 755 /usr/local/bin/lab-indir && mkdir -p /opt/lab/indir /opt/lab/jars

# DuckDB komut satırı ve sabitlenmiş eklentiler (avro, httpfs, iceberg)
RUN lab-indir /opt/lab/indir/duckdb-cli.tar.gz sha256 \
        c6507206baf7793c6013dbd82368469a45f20dc0e17a6f92f204602f652ed2bc \
        "https://install.duckdb.org/v${DUCKDB_SURUM}/duckdb-cli-linux-amd64.tar.gz" \
 && tar -xzf /opt/lab/indir/duckdb-cli.tar.gz -C /usr/local/bin duckdb \
 && chmod 755 /usr/local/bin/duckdb \
 && rm /opt/lab/indir/duckdb-cli.tar.gz \
 && lab-indir /opt/lab/indir/avro.duckdb_extension.gz sha256 \
        35447cb42ade2f723f53416ee336dc9ee30ba3584f290e01165398c80f56fd92 \
        "https://extensions.duckdb.org/v${DUCKDB_SURUM}/linux_amd64/avro.duckdb_extension.gz" \
 && lab-indir /opt/lab/indir/httpfs.duckdb_extension.gz sha256 \
        ee6c7d7e60a5da1b6f6bf6156b4298b55ddce0496a5bfe628bd6ab6d47eb8e3e \
        "https://extensions.duckdb.org/v${DUCKDB_SURUM}/linux_amd64/httpfs.duckdb_extension.gz" \
 && lab-indir /opt/lab/indir/iceberg.duckdb_extension.gz sha256 \
        ddc8e8f4af60e6e3accffa1b38043c328c810db91215d6299f29cc933655bf1a \
        "https://extensions.duckdb.org/v${DUCKDB_SURUM}/linux_amd64/iceberg.duckdb_extension.gz"

# Apache Polaris: Iceberg REST kataloğu
RUN lab-indir /opt/lab/indir/polaris.tgz sha512 \
        22cc37ebc8b7bd4288cd937cb5b332fbfb83e3b5bbf36a3a9c4326d48b37b5d47d2a1d3aa83e9071b508ac68cc802ef84e4ad647081839675082cfd48422341f \
        "https://archive.apache.org/dist/polaris/${POLARIS_SURUM}/polaris-bin-${POLARIS_SURUM}.tgz" \
        "https://dlcdn.apache.org/polaris/${POLARIS_SURUM}/polaris-bin-${POLARIS_SURUM}.tgz" \
 && tar -xzf /opt/lab/indir/polaris.tgz -C /opt/lab \
 && mv /opt/lab/polaris-bin-${POLARIS_SURUM} /opt/lab/polaris \
 && rm /opt/lab/indir/polaris.tgz

# Apache Kafka (KRaft, tek düğüm)
RUN lab-indir /opt/lab/indir/kafka.tgz sha512 \
        f5ceba8a265ab6bb2d68362b1f6859a95e15d60ef92ba83b43fdf065b557dc18e98d6383c15b9977320e25b3a2c8b6f11decb17b0fa6c0f163423793a0eb95cb \
        "https://archive.apache.org/dist/kafka/${KAFKA_SURUM}/kafka_2.13-${KAFKA_SURUM}.tgz" \
        "https://dlcdn.apache.org/kafka/${KAFKA_SURUM}/kafka_2.13-${KAFKA_SURUM}.tgz" \
 && tar -xzf /opt/lab/indir/kafka.tgz -C /opt/lab \
 && mv /opt/lab/kafka_2.13-${KAFKA_SURUM} /opt/lab/kafka \
 && rm /opt/lab/indir/kafka.tgz

# Spark için Iceberg çalışma paketi (Spark 4.1, Scala 2.13)
RUN lab-indir /opt/lab/jars/iceberg-spark-runtime-4.1_2.13-${ICEBERG_SURUM}.jar sha512 \
        ac1e2cb00970309f0c6bf241fabf334aef373c1f3e3b443181d429d5f2c0903ace47df9cfc1d55c95807a096cf405ae0a8868831b9e9eb5696dfdb6380587f38 \
        "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.1_2.13/${ICEBERG_SURUM}/iceberg-spark-runtime-4.1_2.13-${ICEBERG_SURUM}.jar"

# Python ortamları: lab, Airflow, dbt v2 ve dbt Core 1.12 ayrı sanal ortamlarda durur
RUN pip install --no-cache-dir "uv==${UV_SURUM}"
COPY lab/gereksinimler/ /opt/lab/gereksinimler/
RUN uv venv /opt/lab/venv --python python3.13 \
 && VIRTUAL_ENV=/opt/lab/venv uv pip install --no-cache -r /opt/lab/gereksinimler/lab.txt
RUN uv venv /opt/lab/airflow --python python3.13 \
 && VIRTUAL_ENV=/opt/lab/airflow uv pip install --no-cache -r /opt/lab/gereksinimler/airflow.txt
RUN uv venv /opt/lab/dbt --python python3.13 \
 && VIRTUAL_ENV=/opt/lab/dbt uv pip install --no-cache -r /opt/lab/gereksinimler/dbt.txt \
 && uv venv /opt/lab/dbt-core --python python3.13 \
 && VIRTUAL_ENV=/opt/lab/dbt-core uv pip install --no-cache -r /opt/lab/gereksinimler/dbt-core.txt \
 && ln -s /opt/lab/airflow/bin/airflow /usr/local/bin/airflow \
 && ln -s /opt/lab/dbt/bin/dbt /usr/local/bin/dbt \
 && ln -s /opt/lab/dbt-core/bin/dbt /usr/local/bin/dbt-core

# Lab komutları her kabukta bulunsun diye yol tanımı oturum açılışına da yazılır
# Taban imajın 00-restore-env.sh betiği PATH'i giriş kabuklarında yeniden yazar; lab betiği adıyla ondan sonra çalışır.
RUN printf 'export PATH=/opt/lab/venv/bin:/opt/lab/kafka/bin:/usr/lib/postgresql/17/bin:$PATH\n' > /etc/profile.d/zz-lab.sh

USER vscode

# DuckDB eklentileri kullanıcının eklenti klasörüne yerel dosyadan kurulur; lab ağdan eklenti indirmez
RUN duckdb -no-agent -c "INSTALL '/opt/lab/indir/avro.duckdb_extension.gz'; INSTALL '/opt/lab/indir/httpfs.duckdb_extension.gz'; INSTALL '/opt/lab/indir/iceberg.duckdb_extension.gz';" \
 && duckdb -no-agent -c "SET autoinstall_known_extensions = false; LOAD iceberg; LOAD httpfs;"
