-- =====================================================
-- RESET TAHUNAN -- Sistem Tes Fisik PMB Poltek Petrokimia
-- =====================================================
-- Dipakai untuk mengosongkan data peserta (dan opsional panitia)
-- menjelang angkatan/tahun baru.
--
-- !!! LANGKAH WAJIB SEBELUM MENJALANKAN INI !!!
--     1. Buka Dashboard aplikasi -> klik tombol Unduh (Export CSV)
--     2. Buka file CSV-nya, pastikan datanya lengkap & benar
--     3. Simpan di tempat aman (Google Drive, dll)
--     Setelah TRUNCATE, data TIDAK BISA dikembalikan.
--
-- Catatan: TRUNCATE hanya mengosongkan BARIS data.
--          Struktur tabel, RLS, fungsi checkin_peserta, index,
--          dan realtime TETAP UTUH -- tidak perlu jalankan setup.sql lagi.
-- =====================================================


-- -----------------------------------------------------
-- OPSI A -- Kosongkan PESERTA saja (paling umum)
-- Pakai ini kalau tim panitia masih sama, hanya ganti peserta.
-- -----------------------------------------------------
TRUNCATE TABLE peserta RESTART IDENTITY;


-- -----------------------------------------------------
-- OPSI B -- Kosongkan PESERTA + PANITIA
-- Hapus tanda komentar (--) di bawah HANYA jika tim panitia
-- juga berganti dan ingin diisi ulang dari awal.
-- -----------------------------------------------------
-- TRUNCATE TABLE panitia RESTART IDENTITY;


-- =====================================================
-- VERIFIKASI -- jalankan untuk memastikan sudah kosong
-- =====================================================
-- SELECT COUNT(*) AS sisa_peserta FROM peserta;   -- harus 0
-- SELECT COUNT(*) AS sisa_panitia FROM panitia;   -- (jika Opsi B dipakai)


-- =====================================================
-- LANGKAH SETELAH RESET:
-- =====================================================
-- 1. Table Editor -> peserta -> Insert -> Import data from CSV
--    (gunakan peserta_template.csv yang sudah diisi data baru)
-- 2. Jika Opsi B dipakai: isi ulang tabel panitia juga
--    (email harus persis sama dengan akun Google Workspace)
-- 3. Buka /dashboard -- pastikan tampil "Belum ada peserta check-in"
-- 4. Test scan 1 peserta dummy untuk memastikan sistem jalan
-- =====================================================
