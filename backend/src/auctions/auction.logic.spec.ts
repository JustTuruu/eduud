import { describe, expect, it } from 'vitest';
import { AuctionSnapshot, computeNewEndsAt, validateBid } from './auction.logic';

const base = (over: Partial<AuctionSnapshot> = {}): AuctionSnapshot => ({
  status: 'live',
  startsAt: new Date('2026-01-01T00:00:00Z'),
  endsAt: new Date('2026-01-01T01:00:00Z'),
  currentPrice: 100,
  increment: 10,
  softCloseSec: 15,
  extendSec: 15,
  hardCloseAt: null,
  lastBidderId: null,
  ...over,
});

describe('validateBid', () => {
  const now = new Date('2026-01-01T00:30:00Z');

  it('идэвхтэй auction дээр bid зөвшөөрнө', () => {
    expect(validateBid(base(), 'u1', now)).toBeNull();
  });

  it('live биш үед татгалзана', () => {
    expect(validateBid(base({ status: 'scheduled' }), 'u1', now)).toBe('NOT_LIVE');
    expect(validateBid(base({ status: 'ended' }), 'u1', now)).toBe('NOT_LIVE');
  });

  it('эхлээгүй үед татгалзана', () => {
    expect(validateBid(base(), 'u1', new Date('2025-12-31T23:59:59Z'))).toBe('NOT_STARTED');
  });

  it('дууссан үед татгалзана', () => {
    expect(validateBid(base(), 'u1', new Date('2026-01-01T01:00:00Z'))).toBe('ALREADY_ENDED');
  });

  it('сүүлийн bidder дахин bid хийхийг татгалзана', () => {
    expect(validateBid(base({ lastBidderId: 'u1' }), 'u1', now)).toBe('ALREADY_LAST_BIDDER');
  });

  it('өөр хэрэглэгч сүүлийн bidder байвал зөвшөөрнө', () => {
    expect(validateBid(base({ lastBidderId: 'u2' }), 'u1', now)).toBeNull();
  });
});

describe('computeNewEndsAt (soft close)', () => {
  it('soft-close цонхноос гадуур бол endsAt өөрчлөгдөхгүй', () => {
    const a = base();
    const now = new Date('2026-01-01T00:30:00Z'); // 30 мин үлдсэн
    expect(computeNewEndsAt(a, now)).toEqual(a.endsAt);
  });

  it('сүүлийн 15 секундэд bid ирвэл now+15s хүртэл сунгана', () => {
    const a = base(); // ends 01:00:00
    const now = new Date('2026-01-01T00:59:50Z'); // 10s үлдсэн
    expect(computeNewEndsAt(a, now)).toEqual(new Date('2026-01-01T01:00:05Z'));
  });

  it('сунгалт одоогийн endsAt-ээс богино бол endsAt хэвээр (богиносгохгүй)', () => {
    const a = base({ softCloseSec: 60, extendSec: 5 }); // цонх 60s, сунгалт 5s
    const now = new Date('2026-01-01T00:59:30Z'); // 30s үлдсэн, now+5s < endsAt
    expect(computeNewEndsAt(a, now)).toEqual(a.endsAt);
  });

  it('hard close-оос хэтрүүлэхгүй', () => {
    const a = base({ hardCloseAt: new Date('2026-01-01T01:00:03Z') });
    const now = new Date('2026-01-01T00:59:55Z'); // 5s үлдсэн, now+15s > hardClose
    expect(computeNewEndsAt(a, now)).toEqual(new Date('2026-01-01T01:00:03Z'));
  });

  it('hard close дээр тулсан үед цааш сунгагдахгүй', () => {
    const hard = new Date('2026-01-01T01:00:00Z');
    const a = base({ hardCloseAt: hard, endsAt: hard });
    const now = new Date('2026-01-01T00:59:59Z');
    expect(computeNewEndsAt(a, now)).toEqual(hard);
  });
});
