-- Remove the app-level hourly quota. Supabase's own platform protections remain.
DROP FUNCTION IF EXISTS public.consume_vendor_signup_attempt(text);
DROP TABLE IF EXISTS public.vendor_signup_rate_limits;
