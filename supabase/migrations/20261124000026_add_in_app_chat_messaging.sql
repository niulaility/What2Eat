-- ==============================================================================
-- What2Eat Migration 26: In-App Chat Messaging
-- Supports:
--   - Realtime communication between customers and food vendors
--   - 1-to-1 conversation threads with unread tracking & message history
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABLE: conversations (1-to-1 chat thread between Customer & Vendor)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    vendor_id UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT unique_customer_vendor_chat UNIQUE (customer_id, vendor_id)
);

CREATE INDEX IF NOT EXISTS idx_conversations_customer ON public.conversations(customer_id);
CREATE INDEX IF NOT EXISTS idx_conversations_vendor ON public.conversations(vendor_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON public.conversations(last_message_at DESC);

-- ------------------------------------------------------------------------------
-- 2. TABLE: messages (Individual chat messages)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT message_content_not_empty CHECK (char_length(trim(content)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON public.messages(sender_id);

-- ------------------------------------------------------------------------------
-- 3. TRIGGER: Update conversation last_message_at on new message
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.conversations
    SET last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_new_message_conversation ON public.messages;
CREATE TRIGGER trigger_new_message_conversation
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_message();

-- ------------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Conversations: Customer, Vendor owner, or Admin
CREATE POLICY "Conversation participants can view"
    ON public.conversations FOR SELECT TO authenticated
    USING (
        customer_id = auth.uid() 
        OR EXISTS (SELECT 1 FROM public.vendors WHERE id = conversations.vendor_id AND user_id = auth.uid())
        OR public.is_admin()
    );

CREATE POLICY "Customers can initiate conversation with approved vendor"
    ON public.conversations FOR INSERT TO authenticated
    WITH CHECK (
        customer_id = auth.uid()
        AND EXISTS (SELECT 1 FROM public.vendors WHERE id = vendor_id AND status = 'approved' AND is_active = true)
    );

-- Messages: Participants can view and insert
CREATE POLICY "Message participants can view messages"
    ON public.messages FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = messages.conversation_id
          AND (
              c.customer_id = auth.uid()
              OR EXISTS (SELECT 1 FROM public.vendors v WHERE v.id = c.vendor_id AND v.user_id = auth.uid())
              OR public.is_admin()
          )
    ));

CREATE POLICY "Participants can send messages"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_id
              AND (
                  c.customer_id = auth.uid()
                  OR EXISTS (SELECT 1 FROM public.vendors v WHERE v.id = c.vendor_id AND v.user_id = auth.uid())
              )
        )
    );

CREATE POLICY "Recipient can mark messages as read"
    ON public.messages FOR UPDATE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = messages.conversation_id
          AND (
              c.customer_id = auth.uid()
              OR EXISTS (SELECT 1 FROM public.vendors v WHERE v.id = c.vendor_id AND v.user_id = auth.uid())
          )
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = messages.conversation_id
          AND (
              c.customer_id = auth.uid()
              OR EXISTS (SELECT 1 FROM public.vendors v WHERE v.id = c.vendor_id AND v.user_id = auth.uid())
          )
    ));

-- ------------------------------------------------------------------------------
-- 5. REALTIME ENABLEMENT
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 6. PERMISSIONS
-- ------------------------------------------------------------------------------
GRANT SELECT, INSERT ON public.conversations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;
