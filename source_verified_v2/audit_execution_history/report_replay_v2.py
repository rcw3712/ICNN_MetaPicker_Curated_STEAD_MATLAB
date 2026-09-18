from pathlib import Path
import csv,json,hashlib,shutil,zipfile
w=Path(__file__).parent;r=w/'audit_replay_threshold_station_20260918';n=w/'audit_no_training_20260918'
v=json.loads((r/'replay_verification.json').read_text());t=json.loads((r/'threshold/verification.json').read_text());assert v['passed']
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
b=read(r/'threshold/threshold_paired_bootstrap.csv')
def describe(policy,method):
 a=[x for x in b if x['Policy']==policy and x['Phase']=='S' and x['Comparison']==method+' Full3C minus Zonly'];d=[float(x['Delta']) for x in a]
 return f"{min(d):.4f}–{max(d):.4f}; CI pointwise di atas nol {sum(float(x['CI_low'])>0 for x in a)}/27 konfigurasi"
text=f'''# Audit inferensi v2 dan integrasi manuskrip

Audit ini dilakukan tanpa training, pemilihan checkpoint baru, atau estimasi ulang bobot ensemble. Angka utama tetap menggunakan decoder 0,30 / quality 3 / S–P 0,1–30 detik. Hasil merupakan evaluasi retrospektif pada satu split; keberhasilan replay tidak menghilangkan riwayat penggunaan data.

## Verifikasi inferensi

- Semua {v['unique_checkpoints']} checkpoint benar-benar digunakan dalam replay dan hash akhirnya tetap sama.
- Sebanyak 70 set prediksi × 330 rekaman diperiksa pada decoder constrained dan unconstrained. Ketidaksesuaian status: {v['status_mismatches']}; ketidaksesuaian waktu/ketersediaan pick: {v['pick_mismatches']}.
- Selisih maksimum waktu pick: {v['max_pick_difference_seconds']:.6g} detik; toleransi 1e-7 detik. Selisih numerik maksimum quality: {v['max_quality_difference']:.6g}.
- Sebanyak {v['oof_tensors']:,} tensor OOF asli/augmentasi dibangun ulang dari CSV; selisih maksimum {v['max_oof_feature_difference']:.6g}. Sebanyak {v['test_meta_tensors']:,} tensor meta test memiliki selisih maksimum {v['max_test_feature_difference']:.6g}. Toleransi fitur 1e-6.
- Semua {v['code_files']} file kode yang dibekukan sebelum replay tetap sama. Replay memakai MATLAB R2024a dan GPU NVIDIA GeForce RTX 3060 Laptop GPU (6 GiB; driver 610.60).
- Pemeriksaan ini mereproduksi inferensi dan fitur dari model yang sudah dilatih; tidak menguji determinisme retraining atau generalisasi independen. Fitur validation tidak termasuk rekonstruksi tensor ini; bobot ensemble dari validation dipertahankan.

## Threshold

Grid ditetapkan sebelum kalkulasi: peak 0,20/0,30/0,40 × quality P/S 2/3/4 × batas atas S–P 20/30/40 detik. Batas bawah 0,1 detik, uncertain = setengah peak. Semua 27 kombinasi dievaluasi pada 18 stacker penuh dan enam PhaseNetMatched. Tidak ada konfigurasi dipilih berdasarkan test.

| Perbandingan S Full3C minus Z-only | Rentang ΔF1 dan interval |
|---|---|
| Stacker accepted | {describe('accepted','Stack')} |
| PhaseNet accepted | {describe('accepted','PhaseNet')} |
| Stacker detected-only | {describe('strict','Stack')} |
| PhaseNet detected-only | {describe('strict','PhaseNet')} |

CI memakai 10.000 bootstrap sumber (seed 42), conditional pada model dan split, bukan interval simultan atau uji terkoreksi multiplicity. Quality tidak mengubah accepted mask karena detected dan uncertain digabung; 27 konfigurasi menyusut menjadi sembilan kombinasi peak/window untuk accepted scoring. Detected-only tetap memakai accepted P untuk gerbang S. Perubahan jendela S juga mengubah denominator quality. Keunggulan P baseline memiliki interval di bawah nol pada seluruh konfigurasi kedua mode. Untuk S accepted, interval perbandingan metode melintasi nol di seluruh grid; pada S detected-only Z-only, 18/27 interval memihak baseline. Interval komponen P stacker berada di atas nol pada 9/27 konfigurasi accepted dan seluruh detected-only, sehingga interpretasinya bergantung pada kebijakan scoring. Seluruh perbandingan P dan S tersedia dalam CSV, termasuk hasil yang melintasi nol. Rekonstruksi decoder primer cocok pada 24 fit; interval primer mereproduksi audit sebelumnya.

Riwayat threshold Juli/September mendokumentasikan keberadaan nilai, bukan membuktikan kalibrasi awal hanya menggunakan validation. Analisis sensitivitas tidak menyelesaikan ketidakpastian riwayat tersebut.

## Station

Dari 64 network–receiver keys test, 55 juga ada dalam train dan mencakup 318/330 rekaman (211 sumber). Sembilan keys tidak terdapat di train maupun validation: hanya 12 rekaman dari sepuluh sumber. Key tidak membedakan station epoch.

Pada subset kecil tersebut S F1 Full3C/Z-only = 0,8333/0,2593 untuk stacker dan 0,8889/0,2222 untuk PhaseNetMatched. Interval perbandingan metode mencakup nol. Ini diagnostik retrospektif, bukan eksperimen station-held-out dan bukan bukti transfer station yang kuat.

## Integrasi audit terdahulu

- Pemindaian menyeluruh 1.265.657 waveform pada arsip STEAD lokal menemukan tepat satu pasangan untuk masing-masing 2.234 fingerprint terpilih, tanpa konflik source_id. Lingkupnya kesamaan numerik float32 pada versi arsip lokal, bukan near-duplicate atau validitas katalog sumber.
- Dari 330 rekaman test saat ini, 233 sebelumnya berada di train, 46 di validation, dan 51 di test. Sebanyak 196/221 sumber test memiliki riwayat train/validation. Sisa 25 sumber juga pernah menjadi test; belum ada subset development-naive.
- Sensitivitas manual-only berarti evaluasi 287 rekaman/188 sumber dengan kedua arrival berstatus manual; semua model tetap. ΔS stacker 0,2705 [0,2113; 0,3299]. Pada irisan manual dan tanpa riwayat train/validation (20 rekaman/19 sumber), interval kedua metode melintasi nol. Temuan ini dicantumkan, bukan dihilangkan.

## Perubahan dokumen

Main Text memperbarui abstrak, metode, bukti replay, diagnostik dan batas klaim. Supplementary memperbarui S19/S21/S22 dan menambah S23–S27 serta gambar S6–S7. Cover Letter dan Highlights diselaraskan. Tabel utama, hasil primer, persamaan, dan gambar lama dipertahankan. Gambar baru tersedia sebagai PNG 600 dpi dan PDF vektor.

Status pengarsipan v2 tetap pending. Paket ini tidak mengklaim DOI/release baru, tidak menyinkronkan repositori, dan tidak menjalankan training tambahan. Pembacaan cache OOF diubah menjadi blok 128 rekaman pada skrip audit untuk menghindari overhead indeks MAT-file; algoritme, checkpoint, serta kode pipeline tetap sama.

## Isi paket dan penggunaan

- Documents: empat DOCX revisi.
- Figures: seluruh 14 gambar utama dan tujuh gambar supplementary dalam PNG/PDF terpisah; S6–S7 adalah tambahan baru.
- Audit: receipt inferensi, hash, tabel threshold/station, dan ringkasan provenance/manual.
- Scripts: skrip replay, audit, grafik dan integrasi. Jalur lokal di bagian konfigurasi perlu disesuaikan pada komputer lain. Paket ini bukan pengganti checkpoint dan waveform sumber.
- SHA256_MANIFEST.csv: hash seluruh file paket selain manifest itu sendiri.

Indeks fingerprint arsip lengkap dan audit sebelumnya tetap tersedia di paket Audit_NoTraining_20260918; tidak digandakan dalam paket ini. Dokumen yang baru harus digunakan sebagai satu set agar penomoran dan klaim konsisten.
'''
(r/'LAPORAN_VERIFIKASI_INFERENSI_V2.md').write_text(text,encoding='utf-8')
print('Report prepared')
