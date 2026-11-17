# Dealer Operations Portal | Demo

Fictional enterprise dealer-operations portal. Python 3.11 and Node 18+ are required.

Run development mode: `./run_local.bat` (UI `http://localhost:5173`, API `http://localhost:8000`). Run demo mode: `./build_and_serve.bat` (`http://localhost:8000`). Docs are at `/docs`; sign in demo at `/login`.

## Module registry

| Module | Endpoint | Threshold | Keyword |
|---|---|---:|---|
| Booking Claims | `/api/claims/bookings` | 500ms | claim_id |
| In-Transit Claims | `/api/claims/transit` | 1500ms | consignment |
| Parts Stock | `/api/stock` | 1000ms | available_qty |
| E-Invoice | `/api/einvoice` | 1800ms | invoice_no |
| Dealer Sign-in | `/login` | 1000ms | Sign in with SSO |
| Dealer Reports | `/api/reports/monthly` | 3000ms | report_id |
| Parts E-Catalogue | `/api/catalogue` | 1000ms | results |
| Apps Gateway | `/api/gateway/orders` | 1500ms | order_id |

For Site24x7, monitor these API endpoints plus `/health` and `/login`, not React page URLs. Add photo overrides in `frontend/public/img/photos`; SVG artwork remains the fallback. All data is fictional.
