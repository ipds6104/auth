#!/usr/bin/env python3
"""
Sync users and pegawais from SIPEDAS (MySQL: sikendis) to rIDM (Tenant: bps)
Preserving bcrypt password hashes so existing passwords work seamlessly.
"""

import subprocess
import json
import re
import sys
import urllib.request
import urllib.error

RIDM_URL = "http://127.0.0.1:8096"
RIDM_TENANT = "bps"
RIDM_TOKEN = "rpat_gcc6VviV2-Wcif7zVa0bJcToLRHAzXgENo8DfGlKqVw"
MYSQL_CONTAINER = "h139vp1fyu5dz7sgnq6wg984"
MYSQL_USER = "mysql"
MYSQL_PASS = "wH4Q8Wv1PIslZPY0thf1F1PqbiveKcEFnmweBPvUKMZcjSClIraDTd9JcAXUyzQa"
MYSQL_DB = "sikendis"

def get_sikendis_users():
    sql = """
    SELECT 
      u.id, 
      u.name, 
      u.email, 
      u.password,
      p.nip,
      p.nip9,
      p.jabatan,
      p.golongan,
      p.pangkat,
      p.unit_kerja,
      p.nomor_wa,
      p.panggilan,
      GROUP_CONCAT(DISTINCT r.name) as roles
    FROM users u
    LEFT JOIN model_has_roles m ON u.id = m.model_id
    LEFT JOIN roles r ON m.role_id = r.id
    LEFT JOIN pegawais p ON u.email = p.email
    GROUP BY u.id, u.name, u.email, u.password, p.nip, p.nip9, p.jabatan, p.golongan, p.pangkat, p.unit_kerja, p.nomor_wa, p.panggilan
    ORDER BY u.id ASC;
    """
    
    cmd = [
        "docker", "exec", MYSQL_CONTAINER,
        "mysql", "-u", MYSQL_USER, f"-p{MYSQL_PASS}", MYSQL_DB,
        "-B", "-e", sql
    ]
    
    proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
    lines = proc.stdout.strip().split("\n")
    if len(lines) < 2:
        return []
    
    headers = lines[0].split("\t")
    users = []
    
    for line in lines[1:]:
        cols = line.split("\t")
        row = dict(zip(headers, cols))
        users.append(row)
        
    return users

def sanitize_username(email, name, nip):
    if email and "@" in email:
        raw_user = email.split("@")[0].strip().lower()
    elif nip and nip != "NULL":
        raw_user = f"nip_{nip}"
    else:
        raw_user = name.lower()
        
    clean_user = re.sub(r"[^a-z0-9_-]", "", raw_user)
    if not clean_user:
        clean_user = f"user_{nip}" if nip != "NULL" else "user"
    return clean_user

def transform_to_ridm(users):
    ridm_users = []
    seen_usernames = set()
    
    for u in users:
        email = u.get("email")
        if not email or email == "NULL":
            continue
            
        username = sanitize_username(email, u.get("name", ""), u.get("nip"))
        if username in seen_usernames:
            username = f"{username}_{u.get('id')}"
        seen_usernames.add(username)
        
        # Parse roles
        roles_str = u.get("roles")
        roles = []
        if roles_str and roles_str != "NULL":
            roles = [r.strip() for r in roles_str.split(",") if r.strip()]
            
        # Parse attributes
        attrs = {}
        for attr in ["nip", "nip9", "jabatan", "golongan", "pangkat", "unit_kerja", "nomor_wa", "panggilan"]:
            val = u.get(attr)
            if val and val != "NULL":
                attrs[attr] = val.strip()
                
        user_doc = {
            "username": username,
            "email": email.strip().lower(),
            "email_verified": True,
            "status": "active",
            "roles": roles,
            "password_hash": u.get("password"),
            "attributes": attrs
        }
        
        ridm_users.append(user_doc)
        
    return ridm_users

def import_to_ridm(ridm_users, dry_run=True):
    endpoint = f"{RIDM_URL}/admin/tenants/{RIDM_TENANT}/users/import?dry_run={'true' if dry_run else 'false'}"
    req = urllib.request.Request(
        endpoint,
        data=json.dumps(ridm_users).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {RIDM_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "rIDM-Sync/1.0"
        },
        method="POST"
    )
    
    try:
        with urllib.request.urlopen(req) as resp:
            data = resp.read().decode("utf-8")
            return json.loads(data)
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"HTTP Error {e.code}: {err_msg}", file=sys.stderr)
        return {"error": err_msg, "code": e.code}

def main():
    print("1. Mengambil data user & pegawai dari database MySQL sikendis...")
    users = get_sikendis_users()
    print(f"   -> Berhasil mengekstrak {len(users)} pengguna dari sikendis.")
    
    print("2. Mentransformasikan data ke schema rIDM Bulk Import...")
    ridm_payload = transform_to_ridm(users)
    print(f"   -> Siap mengimpor {len(ridm_payload)} user ke tenant '{RIDM_TENANT}'.")
    
    # Save a copy locally for reference
    with open("extracted_users.json", "w") as f:
        json.dump(ridm_payload, f, indent=2)
    print("   -> Dump data tersimpan di extracted_users.json")
    
    print("3. Menjalankan Dry Run validasi rIDM...")
    dry_res = import_to_ridm(ridm_payload, dry_run=True)
    print(f"   -> Hasil Dry Run: {json.dumps(dry_res, indent=2)}")
    
    if dry_res.get("failed", 0) > 0 or "error" in dry_res:
        print("❌ Terdapat error saat validasi dry-run. Proses import dibatalkan.")
        sys.exit(1)
        
    print("4. Menjalankan import resmi ke rIDM...")
    prod_res = import_to_ridm(ridm_payload, dry_run=False)
    print(f"   -> Hasil Import: {json.dumps(prod_res, indent=2)}")
    print("🎉 Selesai! Seluruh data user berhasil disinkronkan ke rIDM.")

if __name__ == "__main__":
    main()
