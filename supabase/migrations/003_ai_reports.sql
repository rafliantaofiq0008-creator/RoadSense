-- Create ai_reports table
create table public.ai_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null references public.road_sessions(id) on delete cascade,
  title text not null,
  report_type text not null default 'diskominfo_scientific_report',
  status text not null default 'completed',
  input_summary jsonb,
  report_markdown text not null,
  model_name text,
  generated_at timestamptz default now(),
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.ai_reports enable row level security;

-- Create policies
create policy "Users can select their own ai_reports"
  on public.ai_reports for select
  using ( auth.uid() = user_id );

create policy "Users can insert their own ai_reports"
  on public.ai_reports for insert
  with check ( auth.uid() = user_id );

create policy "Users can delete their own ai_reports"
  on public.ai_reports for delete
  using ( auth.uid() = user_id );
