FROM apache/airflow:2.9.0-python3.11

USER root

# gcc dibutuhkan untuk meng-compile sebagian library Python saat instalasi
RUN apt-get update && apt-get install -y \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt
