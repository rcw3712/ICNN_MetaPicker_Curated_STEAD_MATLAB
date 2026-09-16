# Audit hasil tambahan dan perubahan klaim 16 September 2026

Audit angka lulus: 288 baris metrik dari 24 tabel prediksi dihitung ulang; 22.830 entri manifest cocok dengan 2.283 berkas unik. Setiap tabel memuat 335 rekaman unik dari 317 sumber. Tidak ditemukan selisih melebihi toleransi numerik.

## Kesimpulan ilmiah

PhaseNetMatched memiliki mean F1 lebih tinggi daripada stacker pada kedua fase dan mode. Interval kondisional mendukung keunggulan baseline untuk P pada kedua mode dan S pada Full3C; interval S Z-only melintasi nol. Selisih S Full3C versus Z-only tetap positif pada seluruh sembilan pasangan base/meta. Tidak ada bukti generalisasi split, stasiun atau wilayah.

| Metode | Mode | Fase | F1 100 ms | SD antar base mean atau seed | MAE ms |
|---|---|---|---:|---:|---:|
| Stack | Full3C | P | 0.8694 | 0.0078 | 81.07 |
| PhaseNetMatched | Full3C | P | 0.9661 | 0.0067 | 21.90 |
| Stack | Full3C | S | 0.5780 | 0.0064 | 682.14 |
| PhaseNetMatched | Full3C | S | 0.6267 | 0.0183 | 216.77 |
| Stack | Zonly | P | 0.8723 | 0.0060 | 126.37 |
| PhaseNetMatched | Zonly | P | 0.9637 | 0.0082 | 26.08 |
| Stack | Zonly | S | 0.3384 | 0.0096 | 939.97 |
| PhaseNetMatched | Zonly | S | 0.3689 | 0.0167 | 469.59 |

## Perubahan dokumen

Abstrak dan kesimpulan kini memakai hasil 3×3 base/meta. Tabel 4–5 dan gambar asli dipertahankan dengan label lingkup base42; Tabel 6–7 memuat eksperimen tambahan. Supplementary S15–S18 memuat hasil per base/per seed, strict scoring, dan akuntansi 106 fits. Cover letter dan highlights diselaraskan. Tidak ada perubahan pada prediksi atau model.

## Batas dan pekerjaan sebelum submission

Baseline adalah adaptasi PhaseNet di MATLAB, bukan implementasi resmi. Batch2, input3 kanal, padding, bias/BN dan initialization berbeda; ini pencocokan data dan decoder, bukan compute budget. SD antar tiga base mean bukan SD sembilan pipeline independen. Bootstrap mengondisikan fitted models dan tidak mencakup ketidakpastian training/split; interval eksploratif tanpa koreksi multiplisitas. Eksperimen tambahan dilakukan setelah evaluasi awal, bukan konfirmasi preregistrasi independen.

DOI v1.2.0 tidak mencakup extension. Paket audit lokal disiapkan untuk publikasi; sinkronisasi repo dan pengarsipan release baru masih perlu dilakukan sebelum mengklaim akses publik hasil tambahan. Tidak ada release/DOI baru yang dibuat pada revisi ini.