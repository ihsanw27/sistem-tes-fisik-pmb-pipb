-- =====================================================
-- SETUP DATABASE — Sistem Tes Fisik PMB Poltek Petrokimia
-- =====================================================
-- Jalankan SEKALI saat instalasi baru, di Supabase > SQL Editor.
-- Aman dijalankan ulang (idempotent) — pakai IF NOT EXISTS / OR REPLACE.
--
-- Setelah ini, isi config SUPABASE_URL & SUPABASE_KEY (anon key) di
-- ketiga file HTML, lalu deploy ke Vercel.
-- =====================================================


-- =====================================================
-- 1. TABEL PESERTA
-- =====================================================
CREATE TABLE IF NOT EXISTS peserta (
  id                      SERIAL PRIMARY KEY,
  nomor_peserta           TEXT UNIQUE NOT NULL,   -- yang di-scan QR (mis. 2026100147)
  nik                     TEXT,
  nama                    TEXT NOT NULL,
  jenis_kelamin           TEXT,                   -- 'L' / 'P'
  jalur                   TEXT,
  jurusan_1               TEXT,
  jurusan_2               TEXT,
  foto                    TEXT,                   -- URL foto (boleh kosong)

  -- Kehadiran (diisi oleh kiosk /checkin via fungsi)
  kehadiran               BOOLEAN DEFAULT FALSE,
  timestamp_kehadiran     TIMESTAMPTZ,

  -- Pos: Verifikasi Administrasi
  lolos_verifikasi        TEXT DEFAULT '',        -- '' | 'Lolos' | 'Tidak Lolos'
  catatan_verifikasi      TEXT DEFAULT '',
  panitia_verifikator     TEXT DEFAULT '',
  timestamp_verifikasi    TIMESTAMPTZ,

  -- Pos: Tes Ketinggian
  lolos_ketinggian        TEXT DEFAULT '',
  catatan_ketinggian      TEXT DEFAULT '',
  panitia_ketinggian      TEXT DEFAULT '',
  timestamp_ketinggian    TIMESTAMPTZ,

  -- Pos: Tes Ruang Sempit dan Gelap
  lolos_sempit            TEXT DEFAULT '',
  catatan_sempit          TEXT DEFAULT '',
  panitia_sempit          TEXT DEFAULT '',
  timestamp_sempit        TIMESTAMPTZ,

  -- Pos: Tes Lari (sistem stik warna)
  stik_merah              INTEGER,
  stik_kuning             INTEGER,
  stik_hijau              INTEGER,
  stik_biru               INTEGER,
  catatan_lari            TEXT DEFAULT '',
  panitia_lari            TEXT DEFAULT '',
  timestamp_lari          TIMESTAMPTZ,

  -- Pos: Kesehatan / Medis
  catatan_medis           TEXT DEFAULT '',
  panitia_medis           TEXT DEFAULT '',
  timestamp_medis         TIMESTAMPTZ
);


-- =====================================================
-- 2. TABEL PANITIA
-- =====================================================
CREATE TABLE IF NOT EXISTS panitia (
  id          SERIAL PRIMARY KEY,
  nama        TEXT NOT NULL,
  penugasan   TEXT NOT NULL,   -- lihat daftar peran di bawah
  jabatan     TEXT,
  email       TEXT UNIQUE NOT NULL   -- HARUS sama persis dgn akun Google Workspace
);

-- Nilai 'penugasan' yang dikenali aplikasi:
--   'Verifikasi Administrasi'        -> pos verifikasi
--   'Tes Lari'                       -> pos tes lari
--   'Tes Ketinggian'                 -> pos tes ketinggian
--   'Tes Ruang Sempit dan Gelap'     -> pos ruang sempit
--   'Kesehatan'                      -> pos medis (bisa hapus catatan medis)
--   'Admin'                          -> SEMUA pos panitia + Dashboard penuh
--   'Viewer'                         -> HANYA Dashboard, terkunci mode Livestream
--   Multi-pos: pisah koma tanpa spasi -> 'Tes Lari,Tes Ketinggian'


-- =====================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- =====================================================
ALTER TABLE peserta ENABLE ROW LEVEL SECURITY;
ALTER TABLE panitia ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama dulu agar aman dijalankan ulang
DROP POLICY IF EXISTS "anon_select_peserta"  ON peserta;
DROP POLICY IF EXISTS "auth_select_peserta"  ON peserta;
DROP POLICY IF EXISTS "auth_update_peserta"  ON peserta;
DROP POLICY IF EXISTS "auth_select_panitia"  ON panitia;

-- PESERTA: anon boleh SELECT (kiosk menampilkan nama setelah scan).
-- Anon TIDAK bisa UPDATE langsung -- hanya lewat fungsi checkin_peserta().
CREATE POLICY "anon_select_peserta" ON peserta
  FOR SELECT TO anon USING (true);

-- PESERTA: panitia login (authenticated) boleh baca & ubah semua.
CREATE POLICY "auth_select_peserta" ON peserta
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "auth_update_peserta" ON peserta
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- PANITIA: login hanya boleh baca baris miliknya sendiri (cek email).
CREATE POLICY "auth_select_panitia" ON panitia
  FOR SELECT TO authenticated USING (auth.email() = email);


-- =====================================================
-- 4. FUNGSI CHECK-IN (anon menulis lewat fungsi, bukan tabel langsung)
-- =====================================================
-- SECURITY DEFINER = berjalan dgn hak postgres, melewati RLS.
-- Hanya mengubah kolom kehadiran + timestamp; tidak menyentuh data tes.
CREATE OR REPLACE FUNCTION public.checkin_peserta(p_nomor TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row    peserta%ROWTYPE;
  v_sudah  BOOLEAN;
BEGIN
  SELECT * INTO v_row
  FROM peserta
  WHERE nomor_peserta = lower(trim(p_nomor));

  IF NOT FOUND THEN
    RETURN json_build_object('found', false);
  END IF;

  v_sudah := v_row.kehadiran;

  IF NOT v_sudah THEN
    UPDATE peserta
    SET kehadiran = true,
        timestamp_kehadiran = now()
    WHERE nomor_peserta = lower(trim(p_nomor));
  END IF;

  RETURN json_build_object(
    'found',          true,
    'already',        v_sudah,
    'nomor_peserta',  v_row.nomor_peserta,
    'nama',           v_row.nama,
    'foto',           v_row.foto
  );
END;
$$;

-- Beri akses panggil fungsi ke kedua role
GRANT EXECUTE ON FUNCTION public.checkin_peserta(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.checkin_peserta(TEXT) TO authenticated;


-- =====================================================
-- 5. INDEX -- menjaga query cepat di skala ribuan baris
-- =====================================================
-- syncData() di panitia & dashboard memfilter kehadiran; index ini bikin instan.
CREATE INDEX IF NOT EXISTS idx_peserta_kehadiran ON peserta (kehadiran);
-- Pencarian nama (fitur cari di portal panitia & dashboard).
CREATE INDEX IF NOT EXISTS idx_peserta_nama      ON peserta (lower(nama));
-- Lookup panitia by email pada setiap login.
CREATE INDEX IF NOT EXISTS idx_panitia_email     ON panitia (lower(email));
-- nomor_peserta sudah UNIQUE -> otomatis ter-index (dipakai fungsi checkin).


-- =====================================================
-- 6. REALTIME -- agar dashboard & panitia update otomatis
-- =====================================================
-- Dibungkus DO block supaya tidak error kalau sudah pernah ditambahkan.
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE peserta;
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'peserta sudah ada di publication realtime, dilewati';
END $$;


-- =====================================================
-- 7. CONTOH ISI PANITIA (hapus komentar & sesuaikan)
-- =====================================================
-- INSERT INTO panitia (nama, penugasan, jabatan, email) VALUES
--   ('Nama Verifikator',  'Verifikasi Administrasi',      'Koordinator', 'verif@poltek-petrokimia.ac.id'),
--   ('Nama Petugas Lari', 'Tes Lari',                     'Anggota',     'lari@poltek-petrokimia.ac.id'),
--   ('Petugas Ketinggian','Tes Ketinggian',               'Anggota',     'tinggi@poltek-petrokimia.ac.id'),
--   ('Petugas Sempit',    'Tes Ruang Sempit dan Gelap',   'Anggota',     'sempit@poltek-petrokimia.ac.id'),
--   ('Tim Medis',         'Kesehatan',                    'Koordinator', 'medis@poltek-petrokimia.ac.id'),
--   ('Petugas Serbaguna', 'Tes Lari,Tes Ketinggian',      'Anggota',     'multi@poltek-petrokimia.ac.id'),
--   ('Administrator',     'Admin',                        'Admin',       'admin@poltek-petrokimia.ac.id'),
--   ('Pimpinan',          'Viewer',                       'Pemantau',    'pimpinan@poltek-petrokimia.ac.id');


-- =====================================================
-- VERIFIKASI SETUP (opsional -- hapus komentar untuk cek)
-- =====================================================
-- SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
-- SELECT proname FROM pg_proc WHERE proname = 'checkin_peserta';
-- SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public';
