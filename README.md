# Sistem Tes Fisik PMB — Poltek Petrokimia

Aplikasi web untuk mengelola **check-in dan penilaian tes fisik** peserta Penerimaan Mahasiswa Baru (PMB). Dibangun dengan HTML statis + Supabase (database & login), di-deploy via Vercel.

> **Untuk pengelola baru:** Dokumen ini ditulis selengkap mungkin. Ikuti urut dari atas. Tidak perlu bisa coding untuk menjalankan — hanya perlu teliti mengikuti langkah.

---

## 1. Gambaran Umum

Sistem terdiri dari **3 halaman**:

| Halaman | URL | Untuk siapa | Fungsi |
|---|---|---|---|
| **Check-in** | `/` atau `/checkin` | Peserta (mandiri) | Scan QR kartu ujian untuk absen kehadiran |
| **Panitia** | `/panitia` | Panitia pos tes | Input nilai tes (lari, ketinggian, dll) via scan |
| **Dashboard** | `/dashboard` | Panitia & pimpinan | Monitor progres real-time + ekspor data |

Semua data tersimpan di **satu tabel `peserta`** di Supabase. Tidak ada server yang perlu dijaga — Vercel dan Supabase menangani semuanya.

---

## 2. Peran (Role) Panitia

Peran ditentukan dari kolom `penugasan` di tabel `panitia`. Tulis persis seperti ini:

| `penugasan` | Akses |
|---|---|
| `Verifikasi Administrasi` | Pos verifikasi di portal panitia |
| `Tes Lari` | Pos tes lari |
| `Tes Ketinggian` | Pos tes ketinggian |
| `Tes Ruang Sempit dan Gelap` | Pos ruang sempit |
| `Kesehatan` | Pos medis (+ bisa hapus catatan medis) |
| `Admin` | **Semua pos panitia** + Dashboard penuh |
| `Viewer` | **Hanya Dashboard, terkunci mode Livestream** (lihat angka statistik saja, tanpa nama peserta, tanpa ekspor) |

**Multi-pos:** pisahkan dengan koma tanpa spasi:
```
Tes Lari,Tes Ketinggian
```

**Catatan peran khusus:**
- **Admin** otomatis dapat akses ke seluruh pos — tidak perlu menulis satu per satu.
- **Viewer** kalau mencoba buka `/panitia` akan otomatis dialihkan ke Dashboard. Cocok untuk pimpinan/tamu yang hanya ingin memantau angka tanpa melihat data pribadi peserta.

---

## 3. Persiapan Setiap Tahun / Angkatan Baru

Sistem **tidak terikat tahun** — tanggal tersimpan otomatis di data. Untuk angkatan baru, cukup ganti datanya:

### Langkah:
1. **Backup data lama dulu** (lihat Bagian 7) — ekspor CSV dari Dashboard.
2. Buka Supabase → **SQL Editor**, jalankan:
   ```sql
   TRUNCATE TABLE peserta;
   -- Opsional, kalau panitia juga berubah:
   TRUNCATE TABLE panitia RESTART IDENTITY;
   ```
3. **Import peserta baru:** Table Editor → `peserta` → Import CSV (pakai `peserta_template.csv`).
4. **Isi panitia baru:** Table Editor → `panitia` → Import CSV, atau INSERT manual.
5. Selesai. Tidak ada kode yang perlu diubah.

> Email panitia **harus sama persis** dengan akun Google Workspace `@poltek-petrokimia.ac.id` yang dipakai login.

---

## 4. Format CSV

### `peserta` (wajib kolom berikut, sisanya dikosongkan)
| Kolom | Isi |
|---|---|
| `nomor_peserta` | Unik, ini yang di-scan QR (mis. `2025-001-TPIP`) |
| `nik` | 16 digit |
| `nama` | Nama lengkap |
| `jenis_kelamin` | `L` atau `P` |
| `jalur` | Jalur pendaftaran |
| `jurusan_1`, `jurusan_2` | Pilihan jurusan (jurusan_2 boleh kosong) |
| `foto` | URL foto (boleh kosong) |

### `panitia`
| Kolom | Isi |
|---|---|
| `nama` | Nama panitia |
| `penugasan` | Lihat Bagian 2 |
| `jabatan` | Bebas (Koordinator/Anggota/dll) |
| `email` | Email Google Workspace, **harus persis** |

---

## 5. Setup Awal (sekali saja, untuk instalasi baru)

1. **Supabase:** buat project → SQL Editor → jalankan seluruh `setup.sql`.
2. **Google OAuth:** buat OAuth Client di Google Cloud Console, masukkan Client ID/Secret ke Supabase → Authentication → Providers → Google.
3. **URL Configuration** di Supabase → Authentication:
   - Site URL: `https://tesfisik.poltek-petrokimia.ac.id`
   - Redirect URLs: tambahkan `/`, `/panitia`, `/dashboard`, dan `/checkin`.
4. **Isi config di 3 file HTML** — ganti `SUPABASE_URL` dan `SUPABASE_KEY` (pakai **anon/public key**, JANGAN service_role).
5. **Deploy ke Vercel** dari repo GitHub. Pastikan `vercel.json` dan `logo.png` ikut.

---

## 6. Mode Gelap (Dark Mode)

Tombol bulan/matahari di pojok kanan bawah setiap halaman. Pilihan tersimpan otomatis per perangkat.

---

## 7. Backup & Hemat Sumber Daya (di luar musim PMB)

### Backup data setelah acara
1. Buka **Dashboard** → klik tombol **unduh (Export CSV)**.
2. Simpan file CSV di tempat aman (Google Drive, dll). Verifikasi isinya.

### Menjaga tetap di Free Tier
Supabase Free Tier muat ratusan ribu baris — satu angkatan tidak akan penuh. Tapi untuk menjaga kebersihan:
1. Pastikan CSV backup sudah benar dan lengkap.
2. Jalankan `TRUNCATE TABLE peserta;` untuk mengosongkan.

### Di luar musim PMB
- **Supabase otomatis "pause"** setelah 7 hari tidak ada aktivitas — tidak memakai sumber daya sama sekali. Saat dibutuhkan lagi, buka dashboard Supabase untuk meng-"resume".
- **Vercel** static hosting praktis gratis saat idle.
- **Tidak perlu VPS.** Sistem ini sepenuhnya serverless — tidak ada yang perlu dimatikan/dinyalakan manual.

> Kalau ingin lebih hemat lagi, pause project Supabase secara manual dari dashboard di luar musim.

---

## 8. Kapasitas & Performa

Diuji secara logika untuk **~5000 peserta + ~100 panitia** dengan koneksi wajar (host & DB di Singapura):

- **Query cepat:** ada index pada `kehadiran`, `nama`, dan `email`. 5000 baris sangat ringan untuk Postgres.
- **Anti–thundering herd:** update real-time di-*debounce* 4 detik. Banyak check-in beruntun tidak membuat 100 perangkat menarik data serentak.
- **Batas Free Tier:** realtime maksimal ~200 koneksi bersamaan. 100 panitia masih aman, tapi pantau di dashboard Supabase saat acara.

**Saran operasional hari-H:**
- Satu perangkat per pos (hindari dua panitia mengedit peserta sama).
- Sediakan **hotspot cadangan** — satu-satunya titik gagal di luar kendali aplikasi adalah koneksi internet venue. Banner merah akan muncul otomatis kalau koneksi terputus.

---

## 9. Keamanan

- Login panitia: **Google OAuth** dibatasi domain `@poltek-petrokimia.ac.id`.
- Check-in peserta (`/`): tanpa login (publik), tapi hanya bisa mengubah status kehadiran lewat fungsi database khusus — tidak bisa menyentuh data tes.
- **Jangan** mengganti anon key dengan service_role key di file HTML.

---

## 10. Troubleshooting Cepat

| Gejala | Solusi |
|---|---|
| Login muter terus | Cek Redirect URLs di Supabase sudah benar |
| "Akses Ditolak" saat login | Email belum ada di tabel `panitia` (harus persis) |
| Logo tidak muncul | Pastikan `logo.png` ada di root repo Vercel |
| Dashboard tidak update | Cek koneksi; pastikan tabel `peserta` ada di publication realtime |
| Data tidak tersimpan | Banner merah = koneksi putus. Coba lagi; draft aman tersimpan lokal |

---

## 11. Struktur File

```
repo/
├── index.html        # Halaman check-in peserta (publik)
├── panitia.html      # Portal input panitia (login)
├── dashboard.html    # Dashboard monitor (login)
├── setup.sql         # Skema database + RLS + fungsi (jalankan sekali)
├── vercel.json       # Aturan URL bersih (/panitia, /dashboard)
├── logo.png          # Logo kampus
├── peserta_template.csv
├── panitia_template.csv
└── README.md         # Dokumen ini
```
