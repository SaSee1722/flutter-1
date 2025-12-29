-- Add is_public column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT true;
-- Update existing records to be public by default (if the column was just added)
UPDATE profiles
SET is_public = true
WHERE is_public IS NULL;