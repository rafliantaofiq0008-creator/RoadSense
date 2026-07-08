-- Create road_photos table
CREATE TABLE IF NOT EXISTS public.road_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.road_sessions(id) ON DELETE CASCADE,
    event_id UUID REFERENCES public.road_events(id) ON DELETE SET NULL,
    segment_index INTEGER,
    storage_bucket TEXT NOT NULL DEFAULT 'road-photos',
    storage_path TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    gps_accuracy DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    vibration DOUBLE PRECISION,
    caption TEXT,
    photo_type TEXT NOT NULL DEFAULT 'manual',
    taken_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS for road_photos
ALTER TABLE public.road_photos ENABLE ROW LEVEL SECURITY;

-- Create policies for road_photos table
CREATE POLICY "Users can view their own photos"
    ON public.road_photos FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own photos"
    ON public.road_photos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own photos"
    ON public.road_photos FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own photos"
    ON public.road_photos FOR DELETE
    USING (auth.uid() = user_id);

-- Storage bucket setup
INSERT INTO storage.buckets (id, name, public, allowed_mime_types, file_size_limit) 
VALUES (
  'road-photos', 
  'road-photos', 
  false, 
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[], 
  10485760 -- 10MB
) ON CONFLICT (id) DO UPDATE SET 
  public = false, 
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::text[],
  file_size_limit = 10485760;

-- Enable RLS on storage.objects if not already enabled (typically is)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Storage policies
CREATE POLICY "Users can upload their own photos"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'road-photos' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'users' AND
        (storage.foldername(name))[2] = auth.uid()::text
    );

CREATE POLICY "Users can view their own photos"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'road-photos' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'users' AND
        (storage.foldername(name))[2] = auth.uid()::text
    );

CREATE POLICY "Users can update their own photos"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'road-photos' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'users' AND
        (storage.foldername(name))[2] = auth.uid()::text
    );

CREATE POLICY "Users can delete their own photos"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'road-photos' AND 
        auth.role() = 'authenticated' AND
        (storage.foldername(name))[1] = 'users' AND
        (storage.foldername(name))[2] = auth.uid()::text
    );
