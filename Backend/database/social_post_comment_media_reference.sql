-- Allows social post comments to include validated photo/video/story attachments.
-- Safe to run more than once; existing comments remain unchanged.
ALTER TABLE public.social_post_comments
  ADD COLUMN IF NOT EXISTS media_reference jsonb;
