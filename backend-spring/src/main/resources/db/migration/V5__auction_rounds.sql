-- Раундын хуваарь: [{"startsAt": ISO, "endsAt": ISO, "durationSec": int}, ...]. NULL бол soft-close дүрэм хэвээр.
ALTER TABLE auctions ADD COLUMN rounds JSONB;
