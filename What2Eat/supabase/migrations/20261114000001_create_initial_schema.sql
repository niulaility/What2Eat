-- ==============================================================================
-- What2Eat - Initial Database Schema Migration
-- Designed for current Flutter UI (Authentication, Customer & Vendor Onboarding)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. ENUMS & TYPES
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('student', 'vendor', 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vendor_status') THEN
        CREATE TYPE vendor_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vendor_doc_type') THEN
        CREATE TYPE vendor_doc_type AS ENUM (
            'ic_front',
            'ic_back',
            'selfie',
            'ssm',
            'kkm',
            'typhoid',
            'kitchen'
        );
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
        CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected');
    END IF;
END $$;

-- 3. REUSABLE TRIGGER FUNCTION: update_updated_at_column
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 4. TABLE: profiles
-- Maps to:
--   - auth_page.dart (Sign in, Customer Registration)
--   - vendor_registration_page.dart (Step 1: Account Information)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'student',
    username TEXT NOT NULL UNIQUE,
    full_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL,
    university TEXT,
    avatar_url TEXT,
    terms_accepted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT username_length_check CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
    CONSTRAINT username_format_check CHECK (username ~ '^[A-Za-z][A-Za-z0-9_]{2,29}$')
);

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Profiles updated_at trigger
DROP TRIGGER IF EXISTS trigger_profiles_updated_at ON public.profiles;
CREATE TRIGGER trigger_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ==============================================================================
-- 5. TABLE: vendors
-- Maps to:
--   - vendor_registration_page.dart (Step 2: Business Information)
--   - vendor_application_pending_page.dart (Status review)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    business_description TEXT NOT NULL,
    business_contact_number TEXT NOT NULL,
    business_address TEXT NOT NULL,
    logo_url TEXT,
    universities_served TEXT[] NOT NULL DEFAULT '{}',
    status vendor_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT business_name_min_length CHECK (char_length(trim(business_name)) >= 2),
    CONSTRAINT business_desc_min_length CHECK (char_length(trim(business_description)) >= 20),
    CONSTRAINT business_addr_min_length CHECK (char_length(trim(business_address)) >= 10)
);

-- Vendors indexes
CREATE INDEX IF NOT EXISTS idx_vendors_user_id ON public.vendors(user_id);
CREATE INDEX IF NOT EXISTS idx_vendors_status ON public.vendors(status);

-- Vendors updated_at trigger
DROP TRIGGER IF EXISTS trigger_vendors_updated_at ON public.vendors;
CREATE TRIGGER trigger_vendors_updated_at
    BEFORE UPDATE ON public.vendors
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ==============================================================================
-- 6. TABLE: vendor_documents
-- Maps to:
--   - vendor_registration_page.dart (Step 3: Document Verification)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vendor_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    document_type vendor_doc_type NOT NULL,
    file_url TEXT NOT NULL,
    verification_status verification_status NOT NULL DEFAULT 'pending',
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Documents index
CREATE INDEX IF NOT EXISTS idx_vendor_documents_vendor ON public.vendor_documents(vendor_id);

-- ==============================================================================
-- 7. AUTOMATIC USER SYNC TRIGGER
-- Automatically creates a public.profiles entry whenever a user signs up via
-- Supabase Auth (reading metadata passed in Flutter auth controllers).
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        role,
        username,
        full_name,
        email,
        phone_number,
        university,
        avatar_url,
        terms_accepted
    )
    VALUES (
        NEW.id,
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student'),
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'full_name',
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'phone_number', ''),
        NEW.raw_user_meta_data->>'university',
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE((NEW.raw_user_meta_data->>'terms_accepted')::boolean, false)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

-- ==============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_documents ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- PROFILES POLICIES
-- ------------------------------------------------------------------------------
-- Anyone authenticated can view user profiles (e.g. to see vendor names)
CREATE POLICY "Profiles are viewable by authenticated users"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Users can update only their own profile
CREATE POLICY "Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ------------------------------------------------------------------------------
-- VENDORS POLICIES
-- ------------------------------------------------------------------------------
-- Public/Authenticated can view approved vendors
CREATE POLICY "Approved vendors are viewable by everyone"
    ON public.vendors
    FOR SELECT
    TO authenticated
    USING (status = 'approved' OR auth.uid() = user_id);

-- Vendors can insert their business application
CREATE POLICY "Vendors can insert their own application"
    ON public.vendors
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Vendors can update their own business information
CREATE POLICY "Vendors can update their own application"
    ON public.vendors
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- VENDOR DOCUMENTS POLICIES (STRICT PRIVACY)
-- IC photos, Typhoid cards and selfies must NEVER be visible to other users!
-- ------------------------------------------------------------------------------
-- Only the vendor who owns the documents (or admins) can view them
CREATE POLICY "Vendors can view their own documents"
    ON public.vendor_documents
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_documents.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );

-- Vendors can upload/insert their own documents
CREATE POLICY "Vendors can insert their own documents"
    ON public.vendor_documents
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.vendors
            WHERE vendors.id = vendor_documents.vendor_id
              AND vendors.user_id = auth.uid()
        )
    );

-- ==============================================================================
-- 9. STORAGE BUCKETS SETUP (Public & Private)
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('vendor-logos', 'vendor-logos', true),
    ('vendor-documents', 'vendor-documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Public read for avatars & logos
CREATE POLICY "Avatars are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

CREATE POLICY "Vendor logos are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'vendor-logos');

-- Storage RLS: Upload access for authenticated users to avatars & logos
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Vendors can upload logos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'vendor-logos');

-- Storage RLS: Strict private access for sensitive vendor verification documents
CREATE POLICY "Vendors can upload their own verification documents"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'vendor-documents' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Vendors can read their own verification documents"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'vendor-documents' AND auth.uid()::text = (storage.foldername(name))[1]);
