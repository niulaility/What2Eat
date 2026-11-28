-- Rate-limit the public vendor-account creation Edge Function by source IP.
CREATE TABLE IF NOT EXISTS public.vendor_signup_rate_limits (
    ip_hash text PRIMARY KEY,
    window_started_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
    attempt_count integer NOT NULL DEFAULT 1,
    CONSTRAINT vendor_signup_attempt_count_positive CHECK (attempt_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_vendor_signup_rate_limits_window
    ON public.vendor_signup_rate_limits(window_started_at);

ALTER TABLE public.vendor_signup_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.vendor_signup_rate_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.vendor_signup_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.consume_vendor_signup_attempt(p_ip_hash text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_attempt_count integer;
BEGIN
    IF p_ip_hash IS NULL OR p_ip_hash = '' THEN
        RETURN false;
    END IF;

    INSERT INTO public.vendor_signup_rate_limits AS current_window (
        ip_hash,
        window_started_at,
        attempt_count
    ) VALUES (
        p_ip_hash,
        pg_catalog.now(),
        1
    )
    ON CONFLICT (ip_hash) DO UPDATE SET
        window_started_at = CASE
            WHEN current_window.window_started_at < pg_catalog.now() - INTERVAL '1 hour'
                THEN pg_catalog.now()
            ELSE current_window.window_started_at
        END,
        attempt_count = CASE
            WHEN current_window.window_started_at < pg_catalog.now() - INTERVAL '1 hour'
                THEN 1
            ELSE current_window.attempt_count + 1
        END
    RETURNING attempt_count INTO v_attempt_count;

    DELETE FROM public.vendor_signup_rate_limits
    WHERE window_started_at < pg_catalog.now() - INTERVAL '2 days';

    RETURN v_attempt_count <= 5;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_vendor_signup_attempt(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_vendor_signup_attempt(text) TO service_role;
