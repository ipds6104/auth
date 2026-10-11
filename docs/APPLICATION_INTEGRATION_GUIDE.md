# 📘 Panduan Integrasi Aplikasi & Tata Kelola RBAC (Application-Managed RBAC)

Dokumen ini adalah panduan standar bagi pengembang di cabang/satker untuk menghubungkan aplikasi baru ke **rIDM (IdP Terpusat)** dengan prinsip **Inovasi Otonom Terkendali (Autonomous Innovation with Guardrails)**.

---

## 🎯 Filosofi Arsitektur: Application-Managed RBAC

1. **Autentikasi Terpusat (AuthN di rIDM):**
   * Aplikasi cabang **TIDAK PERLU** dan **DILARANG** membuat tabel kata sandi, form login manual, atau alur reset password sendiri.
   * Seluruh autentikasi ditangani oleh rIDM (`https://auth.dvlpid.my.id/t/bps`) dengan standar SSO OIDC / SAML 2.0, proteksi Passkey/MFA, dan Argon2id.

2. **Otorisasi Domain Lokal (AuthZ di Aplikasi Cabang):**
   * Setiap aplikasi cabang **memegang kendali 100% atas peran (roles) dan izin (permissions)** di aplikasinya sendiri.
   * Developer aplikasi bebas membuat peran baru (misal: `verifikator_spk`, `approver_bast`, `petugas_lapangan`) langsung di database lokal aplikasi tanpa perlu meminta izin atau mengubah konfigurasi di server rIDM pusat.

---

## 🌐 Parameter OIDC Endpoint (Tenant: `bps`)

| Parameter | Nilai |
|---|---|
| **Issuer Base URL** | `https://auth.dvlpid.my.id/t/bps` |
| **Discovery OIDC** | `https://auth.dvlpid.my.id/t/bps/.well-known/openid-configuration` |
| **JWKS Endpoint** | `https://auth.dvlpid.my.id/t/bps/.well-known/jwks.json` |
| **Authorization Endpoint** | `https://auth.dvlpid.my.id/t/bps/authorize` |
| **Token Endpoint** | `https://auth.dvlpid.my.id/t/bps/token` |
| **UserInfo Endpoint** | `https://auth.dvlpid.my.id/t/bps/userinfo` |
| **End Session / Logout** | `https://auth.dvlpid.my.id/t/bps/sessions/logout` |

---

## 🐘 Implementasi 1: Aplikasi Laravel (Filament / Blade)

### 1. Konfigurasi Client OIDC (`config/services.php`)
```php
'ridm' => [
    'client_id' => env('RIDM_CLIENT_ID'),
    'client_secret' => env('RIDM_CLIENT_SECRET'),
    'redirect' => env('APP_URL') . '/auth/callback',
    'base_url' => 'https://auth.dvlpid.my.id/t/bps',
],
```

### 2. Login Callback & Sinkronisasi User Lokal
Saat pengguna berhasil login di rIDM, aplikasi menerima data profil (NIP, nama, email). Aplikasi mencocokkan akun lokal berdasarkan **NIP**:

```php
namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

class AuthController extends Controller
{
    public function redirectToIdp()
    {
        return Socialite::driver('ridm')->redirect();
    }

    public function handleCallback()
    {
        $idpUser = Socialite::driver('ridm')->user();
        
        // Ekstrak NIP dan klaim institusional dari Token rIDM
        $nip = $idpUser->user['nip'] ?? $idpUser->getId();
        $email = $idpUser->getEmail();
        $name = $idpUser->getName();

        // Cari atau buat user lokal (password dibuat dummy karena auth via rIDM)
        $user = User::firstOrCreate(
            ['nip' => $nip],
            [
                'name' => $name,
                'email' => $email,
                'password' => bcrypt(str()->random(32)),
            ]
        );

        Auth::login($user, remember: true);

        return redirect()->intended('/a'); // Masuk ke Filament Dashboard
    }
}
```

### 3. Pengelolaan Role Lokal (Menggunakan Filament Shield / Spatie)
Aplikasi cabang mengelola role secara mandiri di database lokalnya (`roles` dan `model_has_roles`):
* Admin aplikasi membuka menu **Roles & Permissions** di dalam aplikasi.
* Admin aplikasi menetapkan NIP `199503112022031001` sebagai role `Verifikator Dokumen`.
* Role ini **hanya ada dan hanya berlaku di aplikasi tersebut**, tidak mengotori rIDM maupun aplikasi satker lain.

---

## ⚛️ Implementasi 2: Aplikasi Next.js / React (Auth.js / NextAuth)

```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from "next-auth";

const handler = NextAuth({
  providers: [
    {
      id: "ridm",
      name: "BPS SSO",
      type: "oauth",
      wellKnown: "https://auth.dvlpid.my.id/t/bps/.well-known/openid-configuration",
      authorization: { params: { scope: "openid profile email" } },
      clientId: process.env.RIDM_CLIENT_ID,
      clientSecret: process.env.RIDM_CLIENT_SECRET,
      profile(profile) {
        return {
          id: profile.sub,
          nip: profile.nip,
          name: profile.name,
          email: profile.email,
          satker: profile.unit_kerja,
        };
      },
    },
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.nip = (user as any).nip;
      }
      return token;
    },
    async session({ session, token }) {
      if (token) {
        (session.user as any).nip = token.nip;
      }
      return session;
    },
  },
});

export { handler as GET, handler as POST };
```

---

## 🛡️ Checklist Tata Kelola Keamanan Aplikasi Cabang

Setiap tim pengembang di cabang yang membangun aplikasi wajib mematuhi panduan berikut:

1. **Gunakan NIP sebagai Primary Identifier (`sub` claim):**
   * Jangan gunakan username atau email sebagai kunci utama, karena email atau nama dapat berganti, sedangkan NIP 18 digit bersifat abadi dan unik nasional.
2. **Klaim Tenant & Satker:**
   * Jika aplikasi hanya untuk Satker Mempawah (`6104`), tambahkan pengecekan klaim:
     ```php
     if ($idpUser->user['unit_kerja'] !== '6104') {
         abort(403, 'Aplikasi ini terbatas untuk Satker 6104.');
     }
     ```
3. **Session Lifecycle:**
   * Saat user melakukan logout di aplikasi cabang, redirect pengguna ke endpoint SLO rIDM:
     `https://auth.dvlpid.my.id/t/bps/sessions/logout?post_logout_redirect_uri=https://app.cabang.dvlpid.my.id`
