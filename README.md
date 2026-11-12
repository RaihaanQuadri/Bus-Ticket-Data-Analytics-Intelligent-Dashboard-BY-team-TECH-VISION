# TransitIQ · Bus Ticket Analytics

Next.js dashboard and Python ingestion service for KKRTC ticket and waybill data. The dashboard currently uses clearly labeled demonstration values; live analytics are enabled after Supabase is configured and data is imported.

## Run locally

1. Copy `.env.example` to `.env.local` and provide a Supabase project URL, anon key, and service role key. Keep the service role key server side.
2. In Supabase SQL editor, run `supabase/schema.sql`. Create the first admin profile manually after registering its auth user, for example by setting `role='admin', approved=true` in `profiles`.
3. Install and run the web app: `npm install`, `npm run dev`.
4. Install the worker: `cd worker`, `py -m venv .venv`, `.venv\Scripts\activate`, `pip install -r requirements.txt`, then `uvicorn app.main:app --reload --port 8000`.
5. Copy `worker/.env.example` to the worker environment and set `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and a private `INGESTION_TOKEN` before exposing the service. The worker accepts an authorized signed download URL at `POST /ingest` with `filename`, `waybill_number`, and ISO `service_date`.

## Upload flow

The Next.js `POST /api/uploads/sign` endpoint requires a valid Supabase bearer token belonging to an approved admin or auditor. It returns a signed Storage upload URL for `.csv`, `.xlsx`, or `.ods`. Upload the file from the browser directly to Supabase Storage, then pass its signed download URL to the private worker. Keep Storage bucket `bus-raw-data` private.

The Python cleaner recognizes common ticket column names, combines date and time into UTC timestamps, normalizes known stop aliases with a deterministic map and RapidFuzz fallback, and distinguishes collected cash from uncollected concession dues. `Coll Amt = 0` with `Uncoll Amt > 0` maps to `CONCESSION_ZERO_FARE` and does not create an audit alert. True zero-value tickets, negative amounts, invalid timestamps, and repeated ticket serials are reported. Persisted records use 500-row batches.

## Production notes

- Supabase RLS is enabled for all application tables; access requires an approved profile. Admin and auditor write policies are scoped separately from viewer reads.
- Service role credentials bypass RLS and must only be used in server-side environments.
- Add authenticated sign-in and approval management screens before production deployment. The present dashboard is a responsive UI scaffold and its metrics are sample data, not a live query layer.
- Run `npm run typecheck`, `npm run lint`, and `npm run build` before deployment.
