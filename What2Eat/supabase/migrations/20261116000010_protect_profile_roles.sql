-- The app does not currently edit profiles directly. Remove client UPDATE
-- privileges so users cannot change their own role to admin or vendor.
REVOKE UPDATE ON TABLE public.profiles FROM PUBLIC, anon, authenticated;
