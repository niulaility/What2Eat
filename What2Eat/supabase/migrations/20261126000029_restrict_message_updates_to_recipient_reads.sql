BEGIN;

-- Chat messages are immutable; authenticated recipients may only mark them read.
REVOKE UPDATE ON public.messages FROM authenticated;
REVOKE UPDATE (id, conversation_id, sender_id, content, is_read, created_at)
  ON public.messages FROM authenticated;
GRANT UPDATE (is_read) ON public.messages TO authenticated;

DROP POLICY IF EXISTS "Recipient can mark messages as read" ON public.messages;
CREATE POLICY "Recipient can mark messages as read"
  ON public.messages FOR UPDATE TO authenticated
  USING (
    sender_id <> auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.vendors v
                     WHERE v.id = c.vendor_id AND v.user_id = auth.uid()))
    )
  )
  WITH CHECK (
    is_read = true
    AND sender_id <> auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = messages.conversation_id
        AND (c.customer_id = auth.uid()
          OR EXISTS (SELECT 1 FROM public.vendors v
                     WHERE v.id = c.vendor_id AND v.user_id = auth.uid()))
    )
  );

COMMIT;
