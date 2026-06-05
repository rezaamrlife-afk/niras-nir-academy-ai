-- ============================================================
-- NIRAS AI — Supabase Database Setup
-- Nir Academy
-- ============================================================
-- Run this entire file in Supabase SQL Editor
-- Project: your Supabase project
-- ============================================================


-- ============================================================
-- 1. EXAMS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.exams (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Basic metadata
  title         TEXT NOT NULL DEFAULT 'Untitled Exam',
  subject       TEXT,
  level         TEXT CHECK (level IN ('Beginner','Intermediate','Advanced','Mixed') OR level IS NULL),

  -- Educational context (all optional)
  book_name     TEXT,
  unit_lesson   TEXT,
  topic         TEXT,

  -- Exam content (full JSON — sections + blocks)
  content       JSONB NOT NULL DEFAULT '{"sections":[]}',

  -- Export tracking
  export_count  INTEGER NOT NULL DEFAULT 0,
  last_exported_at TIMESTAMPTZ,

  -- Timestamps
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast user queries
CREATE INDEX IF NOT EXISTS idx_exams_user_id ON public.exams(user_id);
CREATE INDEX IF NOT EXISTS idx_exams_updated_at ON public.exams(updated_at DESC);


-- ============================================================
-- 2. AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_exams_updated_at ON public.exams;
CREATE TRIGGER set_exams_updated_at
  BEFORE UPDATE ON public.exams
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;

-- Teacher can only see their own exams
CREATE POLICY "Users can view own exams"
  ON public.exams FOR SELECT
  USING (auth.uid() = user_id);

-- Teacher can create exams
CREATE POLICY "Users can insert own exams"
  ON public.exams FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Teacher can update own exams
CREATE POLICY "Users can update own exams"
  ON public.exams FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Teacher can delete own exams
CREATE POLICY "Users can delete own exams"
  ON public.exams FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================
-- 4. PROFILES TABLE (optional — stores display name)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 5. VERIFY
-- ============================================================
SELECT
  'exams'    AS table_name,
  COUNT(*)   AS row_count
FROM public.exams

UNION ALL

SELECT
  'profiles' AS table_name,
  COUNT(*)   AS row_count
FROM public.profiles;
