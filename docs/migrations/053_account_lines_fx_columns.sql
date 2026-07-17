-- 053_account_lines_fx_columns.sql
--
-- Defensive / idempotent guard for the per-line FX columns the app relies on
-- for the reconciled Accounts summary (base-currency reconciliation).
--
-- The Dart model (AccountLineModel) already reads and inserts these columns,
-- and invoice_detail_screen writes them when a rate is fetched — but
-- updateAccountLine previously omitted them, so fetched rates never persisted.
-- That code path is now fixed; this migration ensures the columns exist so the
-- update cannot fail on a database that predates them.
--
-- Safe to run on a DB where the columns already exist (IF NOT EXISTS).

ALTER TABLE account_lines
  ADD COLUMN IF NOT EXISTS invoice_currency     text,
  ADD COLUMN IF NOT EXISTS fx_rate_to_base      numeric,
  ADD COLUMN IF NOT EXISTS fx_rate_date         date,
  ADD COLUMN IF NOT EXISTS base_currency_amount numeric;

COMMENT ON COLUMN account_lines.invoice_currency     IS 'ISO 4217 currency of the source invoice line (e.g. USD, SGD).';
COMMENT ON COLUMN account_lines.fx_rate_to_base      IS 'Rate to convert invoice_currency -> case base currency, locked at invoice date.';
COMMENT ON COLUMN account_lines.fx_rate_date         IS 'Date the FX rate was locked.';
COMMENT ON COLUMN account_lines.base_currency_amount IS 'gross_amount converted to the case base currency.';
