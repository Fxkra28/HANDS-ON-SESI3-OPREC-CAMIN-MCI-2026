"""
DAG Airflow untuk pipeline crypto real-time.

Berkas ini hanya berisi struktur dan jadwal — tidak ada logika data di sini.
Logika ETL ditempatkan di dags/scripts/ supaya separation of concerns tetap terjaga.

Alur pipeline:
  CoinGecko API → fetch_crypto.py → data_lake/crypto/crypto_raw.json
                → load_to_clickhouse.py → ClickHouse → Metabase Dashboard
"""

from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime


with DAG(
    dag_id="crypto_realtime_pipeline",
    start_date=datetime(2026, 1, 1),
    # Penjadwalan setiap 10 menit, sejalan dengan pendekatan micro-batch
    schedule_interval="*/10 * * * *",
    # Catchup dimatikan agar Airflow tidak mengeksekusi run yang terlewat sejak start_date
    catchup=False,
    description="Pipeline crypto real-time: CoinGecko → ClickHouse → Metabase",
    tags=["crypto", "realtime", "clickhouse"],
) as dag:

    # BashOperator dipilih alih-alih PythonOperator supaya konsisten dengan pemanggilan
    # manual saat development: cukup jalankan "python script.py" lewat shell.

    fetch_crypto = BashOperator(
        task_id="fetch_crypto",
        bash_command="python /opt/airflow/dags/scripts/fetch_crypto.py",
        # Apabila perintah gagal (return code != 0), Airflow menandai task sebagai FAILED
        # dan Task 2 tidak akan dijalankan — konsistensi data tetap terjaga.
    )

    load_clickhouse = BashOperator(
        task_id="load_to_clickhouse",
        bash_command="python /opt/airflow/dags/scripts/load_to_clickhouse.py",
        # Hanya dijalankan apabila Task 1 berstatus SUCCESS.
    )

    # load_clickhouse baru jalan setelah fetch_crypto sukses.
    # Tujuannya supaya ClickHouse tidak mencoba membaca berkas yang belum tercipta.
    fetch_crypto >> load_clickhouse
