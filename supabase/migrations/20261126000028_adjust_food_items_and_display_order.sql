-- ==============================================================================
-- What2Eat Migration 28: Adjust Food Items & Customization Display Order
-- Applies on top of Migration 25:
--   1. Removes redundant is_available column from public.food_items
--   2. Adds display_order column to public.food_customization_groups
-- ==============================================================================

-- 1. Remove is_available from food_items (catalog items do not need availability)
ALTER TABLE public.food_items 
    DROP COLUMN IF EXISTS is_available;

-- 2. Add display_order to food_customization_groups
ALTER TABLE public.food_customization_groups 
    ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0;
