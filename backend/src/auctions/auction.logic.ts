/**
 * Auction-ы цэвэр логик — DB-ээс хараат бус тул unit test хийхэд хялбар.
 * Бүх хугацаа millisecond epoch биш Date объектоор явна.
 */

export interface AuctionSnapshot {
  status: string;
  startsAt: Date;
  endsAt: Date;
  currentPrice: number;
  increment: number;
  softCloseSec: number;
  extendSec: number;
  hardCloseAt: Date | null;
  lastBidderId: string | null;
}

export type BidRejection =
  | 'NOT_LIVE'
  | 'NOT_STARTED'
  | 'ALREADY_ENDED'
  | 'ALREADY_LAST_BIDDER';

/** Bid хүлээж авах боломжтой эсэхийг шалгана. null = зөвшөөрнө. */
export function validateBid(a: AuctionSnapshot, userId: string, now: Date): BidRejection | null {
  if (a.status !== 'live') return 'NOT_LIVE';
  if (now < a.startsAt) return 'NOT_STARTED';
  if (now >= a.endsAt) return 'ALREADY_ENDED';
  if (a.lastBidderId === userId) return 'ALREADY_LAST_BIDDER';
  return null;
}

/**
 * Soft-close сунгалт: дуусахад softCloseSec-ээс бага хугацаа үлдсэн үед bid ирвэл
 * `now + extendSec` хүртэл сунгана (гэхдээ одоогийн endsAt-ээс богиносгохгүй,
 * hardCloseAt-ээс хэтрүүлэхгүй).
 */
export function computeNewEndsAt(a: AuctionSnapshot, now: Date): Date {
  const msLeft = a.endsAt.getTime() - now.getTime();
  if (msLeft > a.softCloseSec * 1000) return a.endsAt;

  let extended = new Date(now.getTime() + a.extendSec * 1000);
  if (extended < a.endsAt) extended = a.endsAt;
  if (a.hardCloseAt && extended > a.hardCloseAt) extended = a.hardCloseAt;
  return extended;
}

export const BID_REJECTION_MESSAGES: Record<BidRejection, string> = {
  NOT_LIVE: 'Дуудлага худалдаа идэвхгүй байна.',
  NOT_STARTED: 'Дуудлага худалдаа хараахан эхлээгүй байна.',
  ALREADY_ENDED: 'Дуудлага худалдаа дууссан байна.',
  ALREADY_LAST_BIDDER: 'Та хамгийн сүүлийн санал өгсөн хүн байна.',
};
