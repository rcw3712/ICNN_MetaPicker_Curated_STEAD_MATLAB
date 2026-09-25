# Penyesuaian ESI

Judul: Waveform Identity and Reproducible Source-Grouped Evaluation of Seismic Phase Pickers.

- Fokus pengantar, abstrak, hasil, kesimpulan dan cover letter diarahkan ke identitas waveform, provenance, pemeriksaan alur komputasi dan reproduksi numerik.
- Hasil audit identitas dan replay disajikan sebelum perbandingan picker. Rujukan silang disesuaikan.
- Abstract 215 kata; enam keywords. Highlights lima bullet disediakan sebagai opsional.
- Ditambahkan Duerr et al. (2011), Jover-Alfaro et al. (2026), Vargas-Zamudio et al. (2026), dan sitasi release Zenodo Wibowo et al. (2026). DOI diperiksa saat adaptasi.
- Statements and Declarations serta Online Resource 1 ditambahkan. Disclosure bantuan komputasional AI dipertahankan di Methods; bantuan penulisan dinyatakan terpisah.
- Supplementary disediakan dalam PDF ESM_1 dengan judul, penulis, jurnal dan identitas corresponding author.

## Verifikasi

Isi 7 tabel main dan 27 tabel supplementary identik dengan sumber. Seluruh 23 objek persamaan dan 21 gambar tertanam identik. Koreksi tata letak hanya menjaga header tabel bersama baris pertama. Gambar terpisah disalin tanpa regenerasi numerik.

Word dirender untuk pemeriksaan visual: main 41 halaman, supplementary 26, cover 1, highlights 1. Heading, tabel, grafik dan batas halaman diperiksa; tidak ditemukan teks keluar halaman pada pemindaian layout. Dua heading bermasalah font dan header tabel terpisah telah diperbaiki.

Tidak dilakukan training maupun penghitungan ulang eksperimen. Historical development exposure, fixed-split/conditional inference, batas subset station, status manual metadata, dan keterbatasan resep ekstraksi tetap dinyatakan. Reproduksi numerik tidak disamakan dengan independent predictive confirmation.

## Catatan skrip

Scripts memuat rekam implementasi penyuntingan pada workstation ini, dengan path lokal. Urutan authoring adalah adapt_esi.py lalu finish_esi_layout.py; render_esi_pages.py membaca PDF hasil ekspor Word. Sesuaikan path/dependensi sebelum dipakai pada perangkat lain. Paket ini tidak menggantikan kode ilmiah di release Zenodo.
