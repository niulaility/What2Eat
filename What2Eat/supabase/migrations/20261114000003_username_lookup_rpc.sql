-- Migration 3: Secure username-to-email lookup RPC
-- This allows the login screen to look up a user's email by their username
-- WITHOUT exposing the entire profiles table to anonymous users.
-- SECURITY DEFINER means this function runs with the permissions of its creator
-- (the DB owner), not the calling user — so it bypasses RLS safely.

CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT email
  FROM public.profiles
  WHERE username = p_username
  LIMIT 1;
$$;

-- Lock down who can call this function: only anon and authenticated roles
REVOKE ALL ON FUNCTION public.get_email_by_username(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_email_by_username(TEXT) TO anon, authenticated;
