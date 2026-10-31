-- N20 decision (2026-11-01): chat is deferred to version 1.1. Its tables and
-- earlier migrations stay, but no client can reach them until chat ships with
-- its own routes, RLS review and tests. Contact goes through
-- reveal_seller_phone (call / WhatsApp), which logs contact_logs.
REVOKE ALL ON public.conversations, public.messages FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.update_conversation_timestamp() FROM PUBLIC, anon, authenticated;
