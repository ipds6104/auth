#!/usr/bin/env python3
"""
Update Tenant Branding & Custom CSS for BPS Mempawah SSO in rIDM.
"""

import json
import subprocess
import sys

CSS = """
@import url('https://fonts.googleapis.com/css2?family=Google+Sans:wght@400;500;600;700&family=Google+Sans+Text:wght@400;500;600&display=swap');

*, *::before, *::after, html, body, input, button, select, textarea, h1, h2, h3, h4, p, span, a, label {
    font-family: 'Google Sans', 'Google Sans Text', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
}

body {
    background: radial-gradient(circle at 50% -10%, #dbeafe 0%, #eff6ff 35%, #f8fafc 100%) !important;
    background-attachment: fixed !important;
    min-height: 100vh !important;
}

/* Tenant Header (Outside Card) */
body > div > header.mb-6 {
    display: flex !important;
    flex-direction: row !important;
    align-items: center !important;
    justify-content: center !important;
    margin-bottom: 2rem !important;
    gap: 1rem !important;
}

body > div > header.mb-6 img {
    max-height: 3.75rem !important;
    max-width: 14rem !important;
    filter: drop-shadow(0 3px 6px rgba(0, 91, 170, 0.18)) !important;
    transition: transform 0.2s ease !important;
}

body > div > header.mb-6 img:hover {
    transform: scale(1.02) !important;
}

body > div > header.mb-6 span {
    font-size: 1.125rem !important;
    font-weight: 700 !important;
    color: #003870 !important;
    letter-spacing: -0.01em !important;
    text-transform: uppercase !important;
    line-height: 1.25 !important;
}

/* Card Container */
main.card-in {
    border-radius: 1.25rem !important;
    border: 1px solid rgba(0, 91, 170, 0.14) !important;
    background: #ffffff !important;
    box-shadow: 0 20px 45px -15px rgba(0, 91, 170, 0.18), 0 0 0 1px rgba(0, 91, 170, 0.05) !important;
    padding: 2.25rem 2.25rem !important;
    position: relative !important;
}

/* Subtle top colored stripe like BPS */
main.card-in::before {
    content: '' !important;
    position: absolute !important;
    top: 0 !important;
    left: 1.5rem !important;
    right: 1.5rem !important;
    height: 4px !important;
    background: linear-gradient(90deg, #0093dd 0%, #005baa 50%, #eb891b 80%, #68b92e 100%) !important;
    border-radius: 0 0 4px 4px !important;
}

/* Form Header Inside Card */
main.card-in header {
    display: block !important;
    text-align: left !important;
    margin-bottom: 1.5rem !important;
}

main.card-in header h1 {
    font-size: 1.625rem !important;
    font-weight: 700 !important;
    color: #0f172a !important;
    letter-spacing: -0.02em !important;
    margin-bottom: 0.375rem !important;
    display: block !important;
}

main.card-in header p {
    color: #64748b !important;
    font-size: 0.875rem !important;
    display: block !important;
}

/* Input Fields with proper SVG Icons */
input:not([type="checkbox"]):not([type="password"]) {
    border-radius: 0.625rem !important;
    border: 1.5px solid #cbd5e1 !important;
    background-color: #f8fafc !important;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23005baa' stroke-width='2'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z'/%3E%3C/svg%3E") !important;
    background-repeat: no-repeat !important;
    background-position: left 0.85rem center !important;
    background-size: 1.25rem 1.25rem !important;
    padding: 0.75rem 0.875rem 0.75rem 2.75rem !important;
    font-size: 0.9375rem !important;
    transition: all 0.2s ease !important;
}

input[type="password"] {
    border-radius: 0.625rem !important;
    border: 1.5px solid #cbd5e1 !important;
    background-color: #f8fafc !important;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%23005baa' stroke-width='2'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z'/%3E%3C/svg%3E") !important;
    background-repeat: no-repeat !important;
    background-position: left 0.85rem center !important;
    background-size: 1.25rem 1.25rem !important;
    padding: 0.75rem 2.5rem 0.75rem 2.75rem !important;
    font-size: 0.9375rem !important;
    transition: all 0.2s ease !important;
}

input:not([type="checkbox"]):focus {
    border-color: #005BAA !important;
    background-color: #ffffff !important;
    box-shadow: 0 0 0 3px rgba(0, 91, 170, 0.16) !important;
    outline: none !important;
}

label {
    font-weight: 500 !important;
    font-size: 0.875rem !important;
    color: #334155 !important;
    margin-bottom: 0.375rem !important;
}

/* Primary Button */
button[type="submit"], button.bg-accent {
    background: linear-gradient(135deg, #005BAA 0%, #004580 100%) !important;
    color: #ffffff !important;
    border-radius: 0.625rem !important;
    font-weight: 600 !important;
    font-size: 0.9375rem !important;
    padding: 0.75rem 1rem !important;
    box-shadow: 0 4px 14px rgba(0, 91, 170, 0.3) !important;
    transition: all 0.2s ease !important;
    border: none !important;
    cursor: pointer !important;
}

button[type="submit"]:hover, button.bg-accent:hover {
    background: linear-gradient(135deg, #004d90 0%, #003666 100%) !important;
    box-shadow: 0 6px 18px rgba(0, 91, 170, 0.4) !important;
    transform: translateY(-1px) !important;
}

a {
    color: #005BAA !important;
    font-weight: 500 !important;
    text-decoration: none !important;
    transition: color 0.15s ease !important;
}

a:hover {
    color: #003666 !important;
    text-decoration: underline !important;
}

input[type="checkbox"] {
    border-radius: 0.25rem !important;
    border: 1.5px solid #94a3b8 !important;
    accent-color: #005BAA !important;
}

footer, div.text-muted, [class*="Secured"] {
    font-size: 0.8125rem !important;
    color: #64748b !important;
}
""".strip()

def main():
    branding = {
        "logo_url": "https://admin.dvlpid.my.id/bps_logo.svg",
        "favicon_url": "https://admin.dvlpid.my.id/bps_logo.svg",
        "primary_color": "#005BAA",
        "background_color": "#f8fafc",
        "support_url": "https://mempawahkab.bps.go.id",
        "custom_css": CSS,
        "links": [
            {"label": "Website BPS Mempawah", "url": "https://mempawahkab.bps.go.id"},
            {"label": "Portal SIPEDAS", "url": "https://admin.dvlpid.my.id"}
        ]
    }

    branding_json = json.dumps(branding)
    sql = f"""
    SET app.bypass_rls = 'on';
    UPDATE tenants
    SET display_name = 'SSO BPS Kabupaten Mempawah',
        settings = jsonb_set(settings, '{{branding}}', '{branding_json.replace("'", "''")}'::jsonb)
    WHERE slug = 'bps';
    """

    print("Mengupdate branding tenant bps di database PostgreSQL...")
    p = subprocess.run(
        ["docker", "exec", "-i", "ridm-postgres", "psql", "-U", "ridm_app", "-d", "ridm"],
        input=sql.encode('utf-8'),
        capture_output=True,
        check=True
    )
    print("Database Output:", p.stdout.decode().strip())

    print("Membersihkan cache tenant di Valkey...")
    p2 = subprocess.run(
        ["docker", "exec", "ridm-valkey", "valkey-cli", "del", "ridm:tenant:slug:bps"],
        capture_output=True,
        check=True
    )
    print("Valkey Output:", p2.stdout.decode().strip())
    print("Sukses menerapkan branding SSO BPS Kabupaten Mempawah!")

if __name__ == "__main__":
    main()
