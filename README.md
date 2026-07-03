# Zimbra Monitor Script

Kumpulan script monitoring untuk membantu administrator Zimbra dalam melakukan pengecekan kesehatan layanan, pemantauan resource server, validasi antrian email, serta troubleshooting operasional harian.

## Features

- Monitoring status service Zimbra
- Monitoring penggunaan CPU, Memory, dan Disk
- Output sederhana dan mudah diotomatisasi
- Kirim notifikasi ke telegram

## Requirements
- Telegram token dan Chat ID
- Bash Shell
- Akses user `zimbra` atau `root`

## Usage
- Konfigurasi token dan chat id telegram di file telegram.conf
- Ubah ownership file server-info.sh dan telegram.conf menjadi milik root
  ```bash
  chown root:root telegram.conf server-info.sh
- Ubah permission file telegram.conf menjadi 600
  ```bash
  chmod 600 telegram.conf
- Ubah permission file server-info.sh menjadi 700
  ```bash
  chmod 700 server-info.sh
- Jalankan script sesuai kebutuhan monitoring
  ```bash
  ./server-info.sh
- Buat crontab untuk script server-info.sh

## Disclaimer
Script ini dibuat berdasarkan kebutuhan operasional di lingkungan produksi dan disediakan apa adanya (as-is). Pastikan melakukan pengujian terlebih dahulu sebelum digunakan pada sistem produksi.
