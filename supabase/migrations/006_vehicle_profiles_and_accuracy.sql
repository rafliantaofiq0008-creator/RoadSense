-- Phase 12: Real-World Accuracy Engine Migration

-- Create Vehicle Profiles table
CREATE TABLE IF NOT EXISTS public.vehicle_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    vehicle_type TEXT DEFAULT 'motorcycle',
    motorcycle_type TEXT,
    suspension_type TEXT,
    phone_mount TEXT,
    baseline_mean DOUBLE PRECISION NOT NULL,
    baseline_std DOUBLE PRECISION NOT NULL,
    baseline_rms DOUBLE PRECISION NOT NULL,
    baseline_peak95 DOUBLE PRECISION NOT NULL,
    threshold_config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on vehicle_profiles
ALTER TABLE public.vehicle_profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own vehicle profiles
CREATE POLICY "Users can view their own vehicle profiles"
ON public.vehicle_profiles
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own vehicle profiles
CREATE POLICY "Users can insert their own vehicle profiles"
ON public.vehicle_profiles
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own vehicle profiles
CREATE POLICY "Users can update their own vehicle profiles"
ON public.vehicle_profiles
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own vehicle profiles
CREATE POLICY "Users can delete their own vehicle profiles"
ON public.vehicle_profiles
FOR DELETE
USING (auth.uid() = user_id);

-- Add Accuracy Diagnostic Fields to road_events
ALTER TABLE public.road_events 
    ADD COLUMN IF NOT EXISTS confidence_score INTEGER,
    ADD COLUMN IF NOT EXISTS vertical_peak DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS lateral_peak DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS jerk_peak DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS gyro_magnitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS heading_change_rate DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS speed_at_event DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS validation_status TEXT,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS vehicle_profile_id UUID REFERENCES public.vehicle_profiles(id) ON DELETE SET NULL;

-- Add Distance Field to road_sessions
ALTER TABLE public.road_sessions
    ADD COLUMN IF NOT EXISTS estimated_distance_km DOUBLE PRECISION;
