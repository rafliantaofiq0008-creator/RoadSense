-- Migration 007: Road Segment Analyses
-- Description: Creates table to store distance-speed-vibration analysis per 100m segment.

CREATE TABLE IF NOT EXISTS public.road_segment_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.road_sessions(id) ON DELETE CASCADE,
    segment_index INTEGER NOT NULL,
    distance_start_m DOUBLE PRECISION NOT NULL,
    distance_end_m DOUBLE PRECISION NOT NULL,
    segment_length_m DOUBLE PRECISION NOT NULL,
    readings_count INTEGER NOT NULL DEFAULT 0,
    avg_speed_kmh DOUBLE PRECISION,
    max_speed_kmh DOUBLE PRECISION,
    avg_vibration DOUBLE PRECISION,
    max_vibration DOUBLE PRECISION,
    vertical_peak DOUBLE PRECISION,
    jerk_peak DOUBLE PRECISION,
    lateral_peak DOUBLE PRECISION,
    gps_accuracy_avg DOUBLE PRECISION,
    event_count INTEGER NOT NULL DEFAULT 0,
    pothole_count INTEGER NOT NULL DEFAULT 0,
    severe_pothole_count INTEGER NOT NULL DEFAULT 0,
    speed_bump_count INTEGER NOT NULL DEFAULT 0,
    data_confidence_level TEXT NOT NULL DEFAULT 'low',
    road_condition TEXT NOT NULL DEFAULT 'not_assessed',
    condition_score DOUBLE PRECISION,
    recommendation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT unique_session_segment UNIQUE (session_id, segment_index)
);

-- Enable RLS
ALTER TABLE public.road_segment_analyses ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can select their own segment analyses" 
    ON public.road_segment_analyses FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own segment analyses" 
    ON public.road_segment_analyses FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own segment analyses" 
    ON public.road_segment_analyses FOR UPDATE 
    USING (auth.uid() = user_id) 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own segment analyses" 
    ON public.road_segment_analyses FOR DELETE 
    USING (auth.uid() = user_id);
