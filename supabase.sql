-- สมุดตามคำบอก: leaderboard database
-- Run once in Supabase → SQL Editor → New query → paste everything → Run.
-- The live (Kahoot-style) rooms use Supabase Realtime and need no tables.

-- Every finished round is one row. Rankings add the rows up.
create table if not exists public.rounds (
  id          bigint generated always as identity primary key,
  player_id   text        not null check (char_length(player_id) between 8 and 64),
  name        text        not null check (char_length(btrim(name)) between 1 and 24),
  room        text                 check (room is null or room ~ '^[A-Z0-9-]{2,12}$'),
  lang        text        not null check (lang in ('th','en')),
  stage       smallint    not null check (stage between 1 and 6),
  correct     smallint    not null check (correct between 0 and 10),
  points      smallint    not null check (points between 0 and 200),
  created_at  timestamptz not null default now()
);
create index if not exists rounds_created_idx on public.rounds (created_at desc);
create index if not exists rounds_room_idx    on public.rounds (room, created_at desc);
create index if not exists rounds_player_idx  on public.rounds (player_id, created_at desc);

-- Players may add rounds but never read, change or delete raw rows.
-- (explicit grant so this works with "Automatically expose new tables" turned off)
revoke all on public.rounds from anon, authenticated;
grant insert (player_id, name, room, lang, stage, correct, points) on public.rounds to anon, authenticated;
alter table public.rounds enable row level security;
drop policy if exists "anyone can add a round" on public.rounds;
create policy "anyone can add a round" on public.rounds
  for insert to anon, authenticated with check (true);

-- Slow down spam: one round per player every 15 seconds (a real round takes longer).
create or replace function public.rounds_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.rounds
             where player_id = new.player_id
               and created_at > now() - interval '15 seconds') then
    raise exception 'too many rounds, slow down';
  end if;
  new.created_at := now();          -- the server sets the time, not the browser
  new.name := btrim(new.name);
  return new;
end $$;
drop trigger if exists rounds_guard on public.rounds;
create trigger rounds_guard before insert on public.rounds
  for each row execute function public.rounds_guard();

-- Ranking: total points per player, optionally for one class room, one language,
-- and only rounds since a given time (e.g. the start of this week).
create or replace function public.leaderboard(
  p_room  text        default null,
  p_lang  text        default null,
  p_since timestamptz default null,
  p_limit int         default 50
) returns table (player_id text, name text, points bigint, rounds bigint, correct bigint)
language sql stable security definer set search_path = public as $$
  select r.player_id,
         (array_agg(r.name order by r.created_at desc))[1] as name,
         sum(r.points)::bigint  as points,
         count(*)::bigint       as rounds,
         sum(r.correct)::bigint as correct
  from public.rounds r
  where (p_room  is null or r.room = p_room)
    and (p_lang  is null or r.lang = p_lang)
    and (p_since is null or r.created_at >= p_since)
  group by r.player_id
  order by points desc, rounds asc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
grant execute on function public.leaderboard(text, text, timestamptz, int) to anon, authenticated;
