-- 🟢 Wasla Enhancements - Part 1: Schema Improvements

-- 1. Add BlurHash column to ad_media
ALTER TABLE public.ad_media ADD COLUMN IF NOT EXISTS blurhash TEXT;
COMMENT ON COLUMN public.ad_media.blurhash IS 'Compact representation of a placeholder for an image to show while loading.';

-- 2. Advanced Arabic Search Improvements
-- Create a function for Arabic search normalization
CREATE OR REPLACE FUNCTION public.normalize_arabic(text TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN unaccent(text)
    -- Replace Alef variants
    REPLACE(REPLACE(REPLACE(text, 'أ', 'ا'), 'إ', 'ا'), 'آ', 'ا')
    -- Replace Te Marbuta
    REPLACE(text, 'ة', 'ه')
    -- Replace Yeh variants
    REPLACE(text, 'ى', 'ي');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Add a generated column for search (to_tsvector)
-- Note: We combine title and description
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
  setweight(to_tsvector('arabic', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('arabic', coalesce(description, '')), 'B')
) STORED;

-- Create GIN index for search_vector
CREATE INDEX IF NOT EXISTS idx_ads_search_vector ON public.ads USING GIN(search_vector);

-- 3. Chat Enhancements: Add last_message_at to conversations for sorting
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_preview TEXT;

-- Update last_message_at trigger
CREATE OR REPLACE FUNCTION public.update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.conversations
  SET last_message_at = NEW.created_at,
      last_message_preview = substring(NEW.content from 1 for 100)
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_update_conversation_timestamp ON public.messages;
CREATE TRIGGER tr_update_conversation_timestamp
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.update_conversation_timestamp();

-- Enable Realtime for relevant tables (Supabase specific)
-- Check if publication exists first
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
