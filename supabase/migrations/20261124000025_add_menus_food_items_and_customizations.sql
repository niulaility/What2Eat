-- ==============================================================================
-- What2Eat Migration 25: Menus, Food Catalog & Customizations
-- Supports:
--   - Admin: User account suspension / deactivation
--   - Vendor: Food categories, food item catalog, image uploads, customizations
--   - Vendor: Menus for specific dates and meal sessions, ordering & delivery windows
--   - Customer: Menu browsing and customization inspection
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ENUMS & EXTENSIONS
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'meal_session') THEN
        CREATE TYPE public.meal_session AS ENUM (
            'breakfast',
            'lunch',
            'dinner',
            'supper'
        );
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. UPDATE public.profiles (Admin account suspension / deactivation)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS suspension_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_is_active ON public.profiles(is_active);

-- ------------------------------------------------------------------------------
-- 3. TABLE: food_categories (Vendor food categories)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT food_category_name_not_empty CHECK (char_length(trim(name)) >= 1),
    CONSTRAINT unique_vendor_category_name UNIQUE(vendor_id, name)
);

CREATE INDEX IF NOT EXISTS idx_food_categories_vendor ON public.food_categories(vendor_id);

-- ------------------------------------------------------------------------------
-- 4. TABLE: food_items (Vendor food item catalog)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.food_categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT food_item_name_not_empty CHECK (char_length(trim(name)) >= 1)
);

CREATE INDEX IF NOT EXISTS idx_food_items_vendor ON public.food_items(vendor_id);
CREATE INDEX IF NOT EXISTS idx_food_items_category ON public.food_items(category_id);

-- ------------------------------------------------------------------------------
-- 5. TABLE: food_customization_groups (e.g. "Choose 1 Drink", "Choose 3 Sides")
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_customization_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    food_item_id UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    min_selectable INT NOT NULL DEFAULT 1 CHECK (min_selectable >= 0),
    max_selectable INT NOT NULL DEFAULT 1 CHECK (max_selectable >= 1),
    is_required BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT customization_group_min_max_check CHECK (max_selectable >= min_selectable),
    CONSTRAINT customization_group_name_not_empty CHECK (char_length(trim(name)) >= 1)
);

CREATE INDEX IF NOT EXISTS idx_customization_groups_food_item ON public.food_customization_groups(food_item_id);

-- ------------------------------------------------------------------------------
-- 6. TABLE: food_customization_options (e.g. "Iced Lemon Tea (+$1.00)")
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.food_customization_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.food_customization_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    additional_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (additional_price >= 0),
    is_available BOOLEAN NOT NULL DEFAULT true,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT customization_option_name_not_empty CHECK (char_length(trim(name)) >= 1)
);

CREATE INDEX IF NOT EXISTS idx_customization_options_group ON public.food_customization_options(group_id);

-- ------------------------------------------------------------------------------
-- 7. TABLE: menus (Specific date & meal session schedule)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.menus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    menu_date DATE NOT NULL,
    meal_session public.meal_session NOT NULL,
    order_opening_at TIMESTAMPTZ NOT NULL,
    order_closing_at TIMESTAMPTZ NOT NULL,
    delivery_start_time TIME NOT NULL,
    delivery_end_time TIME NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT order_window_valid CHECK (order_closing_at > order_opening_at),
    CONSTRAINT delivery_window_valid CHECK (delivery_end_time > delivery_start_time),
    CONSTRAINT unique_vendor_date_session UNIQUE (vendor_id, menu_date, meal_session)
);

CREATE INDEX IF NOT EXISTS idx_menus_vendor_date ON public.menus(vendor_id, menu_date);
CREATE INDEX IF NOT EXISTS idx_menus_date_session ON public.menus(menu_date, meal_session, is_published);

-- ------------------------------------------------------------------------------
-- 8. TABLE: menu_items (Food items featured on a specific menu)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_id UUID NOT NULL REFERENCES public.menus(id) ON DELETE CASCADE,
    food_item_id UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
    is_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT unique_menu_food_item UNIQUE (menu_id, food_item_id)
);

CREATE INDEX IF NOT EXISTS idx_menu_items_menu ON public.menu_items(menu_id);
CREATE INDEX IF NOT EXISTS idx_menu_items_food ON public.menu_items(food_item_id);

-- ------------------------------------------------------------------------------
-- 9. STORAGE BUCKET: food-images
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'food-images',
    'food-images',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- ------------------------------------------------------------------------------
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.food_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_customization_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_customization_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

-- Categories: Anyone authenticated can view, vendor manages own
CREATE POLICY "Public can view food categories"
    ON public.food_categories FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Vendors manage own food categories"
    ON public.food_categories FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.vendors WHERE id = food_categories.vendor_id AND user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.vendors WHERE id = food_categories.vendor_id AND user_id = auth.uid()));

-- Food Items: Anyone authenticated can view, vendor manages own
CREATE POLICY "Public can view food items"
    ON public.food_items FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Vendors manage own food items"
    ON public.food_items FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.vendors WHERE id = food_items.vendor_id AND user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.vendors WHERE id = food_items.vendor_id AND user_id = auth.uid()));

-- Customization Groups: Viewable by everyone, vendor manages own
CREATE POLICY "Public can view customization groups"
    ON public.food_customization_groups FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Vendors manage own customization groups"
    ON public.food_customization_groups FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.food_items fi
        JOIN public.vendors v ON v.id = fi.vendor_id
        WHERE fi.id = food_customization_groups.food_item_id AND v.user_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.food_items fi
        JOIN public.vendors v ON v.id = fi.vendor_id
        WHERE fi.id = food_customization_groups.food_item_id AND v.user_id = auth.uid()
    ));

-- Customization Options: Viewable by everyone, vendor manages own
CREATE POLICY "Public can view customization options"
    ON public.food_customization_options FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "Vendors manage own customization options"
    ON public.food_customization_options FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.food_customization_groups fcg
        JOIN public.food_items fi ON fi.id = fcg.food_item_id
        JOIN public.vendors v ON v.id = fi.vendor_id
        WHERE fcg.id = food_customization_options.group_id AND v.user_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.food_customization_groups fcg
        JOIN public.food_items fi ON fi.id = fcg.food_item_id
        JOIN public.vendors v ON v.id = fi.vendor_id
        WHERE fcg.id = food_customization_options.group_id AND v.user_id = auth.uid()
    ));

-- Menus: Published menus viewable by everyone, unpublished by vendor/admin
CREATE POLICY "View menus"
    ON public.menus FOR SELECT TO authenticated
    USING (
        is_published = true 
        OR public.is_admin() 
        OR EXISTS (SELECT 1 FROM public.vendors WHERE id = menus.vendor_id AND user_id = auth.uid())
    );

CREATE POLICY "Vendors manage own menus"
    ON public.menus FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.vendors WHERE id = menus.vendor_id AND user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM public.vendors WHERE id = menus.vendor_id AND user_id = auth.uid()));

-- Menu Items: Viewable if menu is accessible, vendor manages own
CREATE POLICY "View menu items"
    ON public.menu_items FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.menus m 
        WHERE m.id = menu_items.menu_id 
          AND (m.is_published = true OR public.is_admin() OR EXISTS (
              SELECT 1 FROM public.vendors v WHERE v.id = m.vendor_id AND v.user_id = auth.uid()
          ))
    ));

CREATE POLICY "Vendors manage own menu items"
    ON public.menu_items FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.menus m
        JOIN public.vendors v ON v.id = m.vendor_id
        WHERE m.id = menu_items.menu_id AND v.user_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.menus m
        JOIN public.vendors v ON v.id = m.vendor_id
        WHERE m.id = menu_items.menu_id AND v.user_id = auth.uid()
    ));

-- Storage: food-images policies
DROP POLICY IF EXISTS "Food images are publicly accessible" ON storage.objects;
CREATE POLICY "Food images are publicly accessible"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'food-images');

DROP POLICY IF EXISTS "Vendors can upload food images" ON storage.objects;
CREATE POLICY "Vendors can upload food images"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'food-images'
        AND EXISTS (
            SELECT 1 FROM public.vendors
            WHERE user_id = auth.uid() AND status = 'approved' AND is_active = true
        )
    );

-- ------------------------------------------------------------------------------
-- 11. PERMISSIONS
-- ------------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_categories TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_customization_groups TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_customization_options TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menus TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_items TO authenticated;
