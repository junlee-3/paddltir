-- Paddler PWA subscribes to postgres_changes on these tables; RLS still filters every event per subscriber.
alter publication supabase_realtime add table sessions, heats, seats, heat_reserves, availability;
