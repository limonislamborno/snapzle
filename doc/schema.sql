-- ====================================================================
-- SNAPZLE (MY PHOTO MY GAME) — Complete All-In-One Database & Storage Schema
-- Version: 1.1.0
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================================================================
-- 1. PROFILES TABLE (Public projection of players)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    avatar_emoji VARCHAR(10) DEFAULT '🦊',
    avatar_gradient INT DEFAULT 0,
    points BIGINT DEFAULT 0,
    level INT DEFAULT 1,
    xp INT DEFAULT 0,
    streak INT DEFAULT 1,
    last_login_date DATE DEFAULT CURRENT_DATE,
    games_played INT DEFAULT 0,
    is_premium BOOLEAN DEFAULT FALSE,
    avatar_url TEXT,
    avatar_cartoon_url TEXT,
    avatar_style VARCHAR(20) DEFAULT 'original',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_points ON public.profiles(points DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- ====================================================================
-- 2. PHOTOS TABLE (Strictly Private to the User)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    photo_name VARCHAR(100) NOT NULL,
    storage_path TEXT NOT NULL,           -- e.g. 'user-photos/<user_id>/<photo_id>.webp'
    diff_storage_path TEXT,               -- generated diff photo for "Find the Difference"
    diff_spots JSONB DEFAULT '[]'::jsonb, -- 5 spots: [{"id": 1, "x": 28, "y": 22, "radius": 15}, ...]
    file_size_kb INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_photos_user_id ON public.photos(user_id);

-- ====================================================================
-- 3. GAME SESSIONS & SCORES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.game_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_type VARCHAR(20) NOT NULL CHECK (game_type IN ('puzzle', 'memory', 'diff', 'slide')),
    difficulty_level INT NOT NULL DEFAULT 0, -- 0: Easy/3x3, 1: Med/4x4, 2: Hard/5x5
    photo_id UUID REFERENCES public.photos(id) ON DELETE SET NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    elapsed_seconds INT DEFAULT 0,
    moves INT DEFAULT 0,
    score INT DEFAULT 0,
    is_perfect BOOLEAN DEFAULT FALSE,
    completed BOOLEAN DEFAULT FALSE,
    verified BOOLEAN DEFAULT FALSE,          -- server-side anti-cheat verification flag
    client_seed TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_game_sessions_user ON public.game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_game_score ON public.game_sessions(game_type, score DESC);
CREATE INDEX IF NOT EXISTS idx_game_sessions_created ON public.game_sessions(created_at);

-- User Game Best Scores (Fast lookup for profiles)
CREATE TABLE IF NOT EXISTS public.user_game_bests (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_type VARCHAR(20) NOT NULL CHECK (game_type IN ('puzzle', 'memory', 'diff', 'slide')),
    best_score INT NOT NULL DEFAULT 0,
    best_time_seconds INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, game_type)
);

-- ====================================================================
-- 4. ACHIEVEMENTS SYSTEM
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.achievements (
    id VARCHAR(30) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    badge_icon VARCHAR(50) NOT NULL,
    rarity VARCHAR(20) DEFAULT 'Common' CHECK (rarity IN ('Common', 'Rare', 'Epic', 'Legendary')),
    reward_points INT DEFAULT 100
);

-- Seed Initial Achievements
INSERT INTO public.achievements (id, name, description, badge_icon, rarity, reward_points) VALUES
('first', 'First Win', 'Complete your first game', 'Trophy', 'Common', 100),
('streak7', 'Week Warrior', '7-day login streak', 'Flame', 'Rare', 250),
('speed', 'Speed Demon', 'Finish a puzzle under 60 seconds', 'Zap', 'Rare', 250),
('perfect', 'Perfect Memory', 'Win Memory Match with no mistakes', 'Brain', 'Epic', 500),
('collector', 'Photo Collector', 'Upload at least 5 photos', 'Images', 'Common', 150),
('champion', 'Top 10', 'Reach the global top 10 leaderboard', 'Crown', 'Legendary', 1000),
('master', 'Puzzle Master', 'Solve a 5x5 puzzle', 'Puzzle', 'Epic', 500),
('eagle', 'Eagle Eye', 'Find all differences with no misses', 'Eye', 'Epic', 500)
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.user_achievements (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievement_id VARCHAR(30) NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

-- ====================================================================
-- 5. DAILY CHALLENGES
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.daily_challenges (
    id VARCHAR(50) PRIMARY KEY,
    challenge_date DATE NOT NULL DEFAULT CURRENT_DATE,
    title VARCHAR(150) NOT NULL,
    game_type VARCHAR(20),
    target_level INT DEFAULT 0,
    goal_count INT DEFAULT 1,
    reward_points INT DEFAULT 200
);

CREATE TABLE IF NOT EXISTS public.user_challenge_progress (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    challenge_id VARCHAR(50) NOT NULL REFERENCES public.daily_challenges(id) ON DELETE CASCADE,
    current_progress INT DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    is_claimed BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, challenge_id)
);

-- ====================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES (DATABASE)
-- ====================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_game_bests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_challenge_progress ENABLE ROW LEVEL SECURITY;

-- Profiles: Public read, private update
DROP POLICY IF EXISTS "Public profiles are viewable by all authenticated users" ON public.profiles;
CREATE POLICY "Public profiles are viewable by all authenticated users"
    ON public.profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Photos: 100% PRIVATE to owner
DROP POLICY IF EXISTS "Users can view their own photos only" ON public.photos;
CREATE POLICY "Users can view their own photos only"
    ON public.photos FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own photos" ON public.photos;
CREATE POLICY "Users can insert their own photos"
    ON public.photos FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own photos" ON public.photos;
CREATE POLICY "Users can update their own photos"
    ON public.photos FOR UPDATE TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own photos" ON public.photos;
CREATE POLICY "Users can delete their own photos"
    ON public.photos FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Game Sessions
DROP POLICY IF EXISTS "Users can view their own game sessions" ON public.game_sessions;
CREATE POLICY "Users can view their own game sessions"
    ON public.game_sessions FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert game sessions" ON public.game_sessions;
CREATE POLICY "Users can insert game sessions"
    ON public.game_sessions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Rankings & Social
DROP POLICY IF EXISTS "Public user game bests viewable" ON public.user_game_bests;
CREATE POLICY "Public user game bests viewable"
    ON public.user_game_bests FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Achievements viewable by all" ON public.achievements;
CREATE POLICY "Achievements viewable by all"
    ON public.achievements FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "User achievements viewable by all" ON public.user_achievements;
CREATE POLICY "User achievements viewable by all"
    ON public.user_achievements FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Daily challenges viewable" ON public.daily_challenges;
CREATE POLICY "Daily challenges viewable"
    ON public.daily_challenges FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "User challenge progress viewable by owner" ON public.user_challenge_progress;
CREATE POLICY "User challenge progress viewable by owner"
    ON public.user_challenge_progress FOR ALL TO authenticated USING (auth.uid() = user_id);

-- ====================================================================
-- 7. STORAGE POLICIES (FOR 'user-photos' PRIVATE BUCKET)
-- ====================================================================
DROP POLICY IF EXISTS "Users can view own photos in storage" ON storage.objects;
CREATE POLICY "Users can view own photos in storage"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'user-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can upload own photos in storage" ON storage.objects;
CREATE POLICY "Users can upload own photos in storage"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'user-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can delete own photos in storage" ON storage.objects;
CREATE POLICY "Users can delete own photos in storage"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'user-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ====================================================================
-- 8. AUTOMATIC PROFILE CREATION TRIGGER ON SIGNUP
-- ====================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    clean_username TEXT;
BEGIN
    clean_username := COALESCE(
        NEW.raw_user_meta_data->>'username',
        'Player_' || SUBSTRING(NEW.id::text, 1, 6)
    );

    INSERT INTO public.profiles (id, username, avatar_emoji, avatar_gradient)
    VALUES (NEW.id, clean_username, '🦊', 0)
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
