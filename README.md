# FITNESS HUB — Ecommerce Platform

Full-stack Django ecommerce platform with seller marketplace, admin dashboard, real-time messaging, maps, multi-language support, and theme system. Built for production on Render.

**Live:** https://ojt-ecommerce-website.onrender.com

[![Render Deployment](https://img.shields.io/badge/deployment-pending-ff69b4)](https://github.com/jeevannar16-web/Ojt-Ecommerce-Website/actions)

---

## Features

### Storefront
- Product catalog — 17 categories, 400+ products, size management
- Product detail pages with image zoom, rating breakdown, reviews, seller info
- Cart with size selection, checkout with map-based delivery picker
- **Distance-based delivery pricing** — standard delivery cost varies by distance (Haversine formula)
- Order tracking with visual timeline and delivery map
- Favorites/wishlist (CSRF-safe AJAX), flash sales, curated sections
- **Responsive design** — mobile-first with hamburger menu

### Authentication & Users
- Register/login with Google OAuth or email/password
- Profile with 4 tabs: Account, Orders, Wishlist, Seller
- Email verification with OTP, password reset with email confirmation
- Email validation (Check-Mail.org + MyEmailVerifier + DNS MX fallback)
- Single active session per user

### Seller Marketplace (Daraz-style)
- Apply to sell, admin approval/rejection with reason
- Seller dashboard: revenue, top products, recent orders
- Product CRUD with image upload and size management
- Order management for own products, storefront page per seller

### Admin Dashboard
- Stats: users, products, orders, revenue, pending sellers, low stock
- Order/seller management, activity log viewer with filters
- Favorites/cart overview, message center

### Messaging System
- Customer ↔ Seller conversations per product
- Seller ↔ Admin support conversations
- Real-time unread badge (polls every 5s), conversation search
- Emoji reactions, pin messages, auto-scroll

### Maps & Location
- Checkout map picker: draggable marker, reverse geocoding, "Use My Location"
- Profile map picker, order history maps, footer map
- Powered by Leaflet + OpenStreetMap (free, no API key)

### Theme System
- 13 themes: Obsidian, Dark, Gold, Neon, Cyberpunk, and more
- Session-persisted, dedicated picker in header and mobile menu

### Multi-Language & Currency
- English, Nepali, Hindi, Korean (custom `|t` filter)
- Auto-currency conversion: USD / NPR / INR / KRW
- Live exchange rates from open.er-api.com with 1-hour cache

---

## Performance Optimizations

| Feature | Detail |
|---------|--------|
| **Cloudinary thumbnails** | Images auto-resized: 300×300 on cards, 600×600 on detail, 100×100 on cart |
| **CSS/JS compression** | Whitenoise CompressedManifestStaticFilesStorage with 1-year cache |
| **Non-blocking CSS** | Google Fonts and Leaflet load asynchronously (`media="print"` trick) |
| **Deferred JS** | All non-critical scripts use `defer` — no render blocking |
| **Database indexes** | 6 indexes on Product model for common filter fields |
| **Page loader** | Instant loading spinner on every navigation click |
| **Low-memory queries** | Home view no longer loads all product IDs into memory |

---

## Quick Start

```bash
git clone <repo-url>
cd Ojt-Ecommerce-Website
cp .env.example .env
# Fill in your env vars (see .env.example)
./start.sh
```

One command creates venv, installs deps, and starts the server. The database (`db.sqlite3`) is included in the repo — products and data come pre-loaded.

Windows: `start.bat`

---

## Database

### Development (SQLite)
Default — no setup needed. Database file `db.sqlite3` is gitignored.

### Production (Neon PostgreSQL)
Migrate from Render PostgreSQL (expires after 90 days) to Neon (free, no expiration): 

1. Export data from running site: visit `/admin-dashboard/export/` as admin
2. Create free database at console.neon.tech
3. Set `DATABASE_URL` in Render env vars to the Neon connection string
4. Deploy — seed data loads automatically from `fixtures/seed_data.json`

---

## Email Configuration

Emails (welcome, OTP, password reset, order confirmations) use a **resilient multi-backend** system that tries providers in order until one succeeds:

1. **Gmail SMTP** — works locally, blocked on Render free tier
2. **Brevo API** — HTTP API (works on Render), free tier: 300 emails/day
3. **SendGrid API** — HTTP API fallback (optional)
4. **Console** — logs to stdout (last resort)

### Setup on Render

| Variable | Required | Description |
|----------|----------|-------------|
| `EMAIL_HOST_USER` | Yes | Gmail address for SMTP |
| `EMAIL_HOST_PASSWORD` | Yes | Gmail App Password |
| `BREVO_API_KEY` | Recommended | Brevo API key (sends on Render) |
| `DEFAULT_FROM_EMAIL` | Yes | Sender address (e.g. `jeevannar16@gmail.com`) |

For Brevo, sign up at brevo.com, create an API key under **SMTP & API → API Keys**, and add it as `BREVO_API_KEY` in Render env vars.

---

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `store/` | Core app: models, views, URLs, templates, admin |
| `users/` | User profiles, auth forms, allauth adapters |
| `homepages/` | Landing page, static pages |
| `localization/` | Translation system, currency, language middleware |
| `verification/` | Email validation, OTP sending |
| `fitness_hub/` | Django project settings, URLs, wsgi |
| `templates/` | All HTML templates by app and feature |
| `static/` | CSS, JS, images (`base/` and `pages/`) |
| `fixtures/` | Seed data (446 products, 17 categories) |
| `.github/workflows/` | GitHub Actions: keep-alive + deployment status |

---

## Tech Stack

- **Backend:** Django 5.0, Python 3.14
- **Database:** SQLite (dev) / **Neon PostgreSQL** (production, free, no expiration)
- **Static files:** Whitenoise (compressed, manifest-based, 1-year cache)
- **Images:** Cloudinary CDN with auto-resize thumbnails
- **Auth:** django-allauth (email + Google OAuth)
- **Email:** Gmail SMTP + Brevo API (HTTP, works on Render free tier) + SendGrid fallback
- **Maps:** Leaflet + OpenStreetMap (no API key)
- **Deployment:** Render (free tier), GitHub Actions (keep-alive + status checks)
- **Error tracking:** Sentry
- **CDN:** Cloudflare (optional, at DNS level)
- **PostgreSQL hosting:** Neon (serverless, 500MB free, never expires)

---

## Security

- All secrets loaded from `.env` — never hardcoded
- `.env` and `db.sqlite3` in `.gitignore`
- Admin panel protected by `@staff_member_required`
- Curation endpoints require staff access
- Sentry DSN and Google OAuth credentials are env-only
- HSTS headers enforced
- CSRF protection on all mutation endpoints
- Password minimum length: 8 characters

---

## Key Decisions

- Database (`db.sqlite3`) is gitignored — seed data lives in `fixtures/seed_data.json`
- Email validation runs all services in parallel; any "invalid" rejects immediately
- Verification email is NEVER auto-sent (prevents bounces)
- Messaging uses polling (not WebSockets) — simpler deployment
- Themes use CSS custom properties with session storage
- Maps use Leaflet — no API key, completely free
- All API keys sourced from `.env` only; no hardcoded secrets
- **Python 3.14** broke Django's `BaseContext.__copy__` — monkey-patched in `fitness_hub/__init__.py` via `object.__new__`. Fixes ALL Django admin 500s.
- Email uses resilient multi-backend (`ResilientEmailBackend`) — tries Gmail SMTP → Brevo API → SendGrid API → console; never crashes on failure
- **Database hosted on Neon** (free, 500MB, no expiration) instead of Render PostgreSQL (expires after 90 days)
- Google OAuth adapter auto-connects existing users by email; stale session state cleared on first-attempt failures

## Troubleshooting

### Google Login Fails on First Attempt
The social login adapter (`users/allauth_adapter.py`) now clears stale OAuth state on errors and logs detailed diagnostics. If Google login still fails on first try, check Render logs for `Social login failed` messages.

### Email Not Delivering on Render
Render free tier blocks outbound SMTP (port 587). The `ResilientEmailBackend` automatically falls back to Brevo HTTP API (port 443). Ensure `BREVO_API_KEY` is set in Render env vars.

### Django Admin 500s (Python 3.14)
If admin pages return 500, the `BaseContext.__copy__` monkey-patch in `fitness_hub/__init__.py` should resolve it. Verify by checking startup logs.
