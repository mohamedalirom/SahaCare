-- Gestion 1 — Profil et dossier médical
-- Table `profiles` : une ligne par utilisateur, protégée par RLS.
-- (Les tables diseases / allergies / medical_history sont gérées par d'autres
--  modules : le module Profil n'y accède qu'en LECTURE.)

create table if not exists public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  full_name           text        not null default '',
  date_of_birth       date,
  biological_sex      text check (biological_sex in ('male', 'female', 'other')),
  blood_group         text check (blood_group in ('A', 'B', 'AB', 'O')),
  rhesus              text check (rhesus in ('+', '-')),
  height_cm           numeric(5, 1) check (height_cm between 50 and 260),
  weight_kg           numeric(5, 1) check (weight_kg between 2 and 400),
  smoking_status      text check (smoking_status in ('never', 'former', 'occasional', 'regular')),
  alcohol_consumption text check (alcohol_consumption in ('none', 'occasional', 'moderate', 'frequent')),
  physical_activity   text check (physical_activity in ('sedentary', 'light', 'moderate', 'intense')),
  updated_at          timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Lecture seule côté profil pour le dossier médical (si les tables existent) :
-- create policy "diseases_select_own" on public.diseases
--   for select using (auth.uid() = user_id);
-- (idem pour allergies et medical_history)
