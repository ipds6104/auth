# 🦀 rIDM Auth Platform (Rust Identity & Access Management)

Platform Identity & Access Management (IAM) generasi baru berbasis **Rust** ([rIDM](https://github.com/ZerosAndOnesLLC/rIDM)), ultra-cepat, hemat memori (~40-60MB RAM), berorientasi performa tinggi, dan berstandar enterprise. Berfungsi sebagai **Central Identity Provider (IdP)** dengan dukungan native **SAML 2.0** dan **OpenID Connect (OIDC)** untuk ekosistem aplikasi BPS Kabupaten Mempawah dan DVL Services.

---

## 🌐 Endpoint & URL Akses Publik

| Layanan | URL | Keterangan |
|---|---|---|
| **Web Portal & Login** | `https://auth.dvlpid.my.id/login/` | Halaman login SSO terpadu |
| **Account Self-Service Console** | `https://auth.dvlpid.my.id/account/` | Portal mandiri ganti password, 2FA/TOTP, Passkey, profile |
| **Admin Console** | `https://auth.dvlpid.my.id/console/` | Manajemen tenant, client SAML/OIDC, dan pengguna |
| **Health Check** | `https://auth.dvlpid.my.id/healthz` | Probe status instance |

---

## 🏢 Realm / Tenant: `bps` (BPS Kabupaten Mempawah)

Dalam arsitektur rIDM, padanan 1 Realm Keycloak adalah **Tenant**. Tenant utama yang telah aktif dan terkonfigurasi adalah **`bps`**.

### 1. SAML 2.0 Identity Provider (IdP) Endpoints
Aplikasi lawas atau enterprise yang memerlukan protokol SAML 2.0 dapat menggunakan spesifikasi berikut:

* **Entity ID (Issuer):** `https://auth.dvlpid.my.id/t/bps`
* **Metadata XML:** `https://auth.dvlpid.my.id/t/bps/saml/metadata`
* **Single Sign-On (SSO):** `https://auth.dvlpid.my.id/t/bps/saml/sso` (Mendukung binding HTTP-Redirect dan HTTP-POST)
* **Single Logout (SLO):** `https://auth.dvlpid.my.id/t/bps/saml/slo` (Mendukung binding HTTP-Redirect dan HTTP-POST)
* **NameID Formats:** `emailAddress`, `persistent`, `transient`, `unspecified`
* **X.509 Signing Certificate:** Tersemat otomatis di dalam dokumen metadata XML.

### 2. OpenID Connect (OIDC) Endpoints
Aplikasi modern (Next.js, React, Vue, Laravel Socialite, Go, Rust, Python FastAPI) dapat mengonsumsi OIDC:

* **Issuer:** `https://auth.dvlpid.my.id/t/bps`
* **Discovery Endpoint:** `https://auth.dvlpid.my.id/t/bps/.well-known/openid-configuration`
* **JWKS URI:** `https://auth.dvlpid.my.id/t/bps/.well-known/jwks.json`
* **Authorization:** `https://auth.dvlpid.my.id/t/bps/authorize`
* **Token:** `https://auth.dvlpid.my.id/t/bps/token`
* **UserInfo:** `https://auth.dvlpid.my.id/t/bps/userinfo`

---

## 👥 Data Pegawai & Sinkronisasi dari `admin.dvlpid.my.id`

Seluruh **37 pengguna** dan **36 pegawai** dari aplikasi SIPEDAS / DOKTER-V (`admin.dvlpid.my.id`) telah diekstrak dan diimpor ke dalam tenant `bps`:

1. **Password Preservasi:**
   * Hash password asli (`bcrypt $2y$12$...`) dipertahankan saat proses bulk import.
   * Pegawai dapat langsung login menggunakan password yang biasa mereka gunakan di SIPEDAS tanpa perlu reset awal.
   * Saat login pertama berhasil, rIDM otomatis meningkatkan (rehash) keamanan kredensial ke standar `argon2id`.

2. **Atribut Kustom Profil (Tersedia di ID Token & UserInfo):**
   * `nip` (NIP 18 digit)
   * `nip9` (NIP 9 digit BPS)
   * `jabatan`
   * `golongan`
   * `pangkat`
   * `unit_kerja`
   * `nomor_wa`
   * `panggilan`

3. **Peran (Roles):**
   * `super_admin`
   * `kepala_satker`
   * `operator_umum`
   * `pegawai`
   * `ppk`
   * `ppspm`
   * `bendahara`

---

## 🛠️ Stack Teknologi

* **Core Engine:** Pure Rust ([Axum](https://github.com/tokio-rs/axum) + [SQLx](https://github.com/launchbadge/sqlx) + [aws-lc-rs](https://github.com/aws/aws-lc-rs))
* **Database:** PostgreSQL 16 (dengan Row-Level Security & skema terisolasi)
* **Session & Cache:** Valkey 9 (Redis compatible)
* **Frontend UI:** Next.js 16 Static Export (terkompilasi langsung di dalam binary rIDM)
* **Reverse Proxy:** Traefik (`coolify-proxy`) & Cloudflare Tunnel

---

## 🚀 Menjalankan & Mengelola Layanan

```bash
# Menjalankan seluruh stack di server
docker compose up -d

# Memeriksa log layanan
docker logs -f ridm-auth

# Menjalankan sinkronisasi ulang data pegawai dari database SIPEDAS
./scripts/sync_sikendis_to_ridm.py
```

---

## 📚 Menghubungkan Aplikasi Baru (Relying Party / SP)

### Contoh OIDC Client (Laravel Socialite):
```php
// config/services.php
'ridm' => [
    'client_id' => env('RIDM_CLIENT_ID'),
    'client_secret' => env('RIDM_CLIENT_SECRET'),
    'redirect' => env('APP_URL') . '/auth/callback',
    'base_url' => 'https://auth.dvlpid.my.id/t/bps',
],
```

### Contoh SAML Service Provider:
1. Buka Admin Console di `https://auth.dvlpid.my.id/console/`
2. Pilih Tenant `bps` ➔ Menu **SAML** ➔ **New Service Provider**
3. Masukkan Entity ID dan ACS URL aplikasi Anda, atau unggah file Metadata SP.
4. Simpan, dan aplikasi langsung terhubung secara SSO!
