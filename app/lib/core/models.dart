// API-ийн хариултуудын модель. Backend-ийн select талбаруудтай яг тааруулсан.

class UserProfile {
  final String id;
  final String phone;
  final String name;
  final String? avatarUrl;
  final String role;
  final int balance;

  UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.balance,
  });

  bool get isAdmin => role == 'admin';

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        phone: j['phone'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        role: (j['role'] ?? 'user') as String,
        balance: (j['balance'] ?? 0) as int,
      );
}

class Bidder {
  final String id;
  final String name;
  final String? avatarUrl;

  Bidder({required this.id, required this.name, this.avatarUrl});

  factory Bidder.fromJson(Map<String, dynamic> j) => Bidder(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarUrl: j['avatarUrl'] as String?,
      );
}

/// Дуудлага худалдааны нэг шат (round): [startsAt, endsAt) ба тоолуурын урт.
class AuctionRound {
  final DateTime startsAt;
  final DateTime endsAt;
  final int durationSec;

  const AuctionRound({
    required this.startsAt,
    required this.endsAt,
    required this.durationSec,
  });

  factory AuctionRound.fromJson(Map<String, dynamic> j) => AuctionRound(
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        durationSec: ((j['durationSec'] ?? 0) as num).toInt(),
      );
}

/// `rounds` талбарыг аюулгүй задлана: null/буруу бол null.
List<AuctionRound>? parseRounds(dynamic raw) {
  if (raw is! List) return null;
  try {
    return raw
        .map((e) => AuctionRound.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return null;
  }
}

/// Нэмэлт шагнал (2-р, 3-р байр): `tokens` = эрх, `item` = бараа.
class AuctionPrize {
  final int place;
  final String kind;
  final int tokens;
  final String title;

  const AuctionPrize({
    required this.place,
    required this.kind,
    this.tokens = 0,
    this.title = '',
  });

  bool get isTokens => kind == 'tokens';

  /// Дэлгэцэнд харагдах шошго: "200 эрх" эсвэл барааны нэр.
  String get label => isTokens ? '$tokens эрх' : title;

  factory AuctionPrize.fromJson(Map<String, dynamic> j) => AuctionPrize(
        place: ((j['place'] ?? 0) as num).toInt(),
        kind: (j['kind'] ?? 'item') as String,
        tokens: ((j['tokens'] ?? 0) as num).toInt(),
        title: (j['title'] ?? '') as String,
      );
}

/// `prizes` талбарыг аюулгүй задлана: null/буруу бол хоосон жагсаалт.
List<AuctionPrize> parsePrizes(dynamic raw) {
  if (raw is! List) return const [];
  final out = <AuctionPrize>[];
  for (final e in raw) {
    try {
      out.add(AuctionPrize.fromJson(Map<String, dynamic>.from(e as Map)));
    } catch (_) {}
  }
  out.sort((a, b) => a.place.compareTo(b.place));
  return out;
}

/// Дууссан дуудлагын байр: 1/2/3-р байрны хэрэглэгч ба авсан шагнал.
class AuctionPlacement {
  final int place;
  final Bidder user;
  final AuctionPrize? prize;

  const AuctionPlacement({required this.place, required this.user, this.prize});

  factory AuctionPlacement.fromJson(Map<String, dynamic> j) {
    final p = j['prize'];
    return AuctionPlacement(
      place: ((j['place'] ?? 0) as num).toInt(),
      user: Bidder.fromJson(Map<String, dynamic>.from(j['user'] as Map)),
      prize: p is Map
          ? AuctionPrize.fromJson({
              ...Map<String, dynamic>.from(p),
              'place': j['place'],
            })
          : null,
    );
  }
}

List<AuctionPlacement> parsePlacements(dynamic raw) {
  if (raw is! List) return const [];
  final out = <AuctionPlacement>[];
  for (final e in raw) {
    try {
      out.add(AuctionPlacement.fromJson(Map<String, dynamic>.from(e as Map)));
    } catch (_) {}
  }
  out.sort((a, b) => a.place.compareTo(b.place));
  return out;
}

/// Одоогийн байрууд: саналын жагсаалтаас (шинэ нь эхэнд) сүүлийн 3 ӨӨР
/// оролцогч — 1-р = хамгийн сүүлд санал өгсөн.
List<AuctionPlacement> currentPlacements(List<BidItem> bids) {
  final seen = <String>{};
  final out = <AuctionPlacement>[];
  for (final b in bids) {
    if (!seen.add(b.user.id)) continue;
    out.add(AuctionPlacement(place: out.length + 1, user: b.user));
    if (out.length == 3) break;
  }
  return out;
}

/// `prize_awarded` socket event-ийн toast текст.
String prizeAwardedMessage(Map<String, dynamic> j) {
  final place = ((j['place'] ?? 0) as num).toInt();
  final prize = AuctionPrize.fromJson(j);
  return prize.isTokens
      ? 'Та $place-р байр эзэлж ${prize.tokens} эрх авлаа'
      : 'Та $place-р байр эзэлж "${prize.title}" шагнал авлаа';
}

class AuctionSummary {
  final String id;
  final String title;
  final List<String> images;
  final int currentPrice;
  final int bidCount;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final Bidder? lastBidder;

  /// Нэг санал бүрээр өсөх үнэ (жагсаалтад ирэхгүй байж болно).
  final int? increment;

  /// Шатуудын хуваарь (байхгүй бол null — хуучин soft-close дүрэм).
  final List<AuctionRound>? rounds;

  /// Нэмэлт шагналууд (2-р, 3-р байр); байхгүй бол хоосон.
  final List<AuctionPrize> prizes;

  AuctionSummary({
    required this.id,
    required this.title,
    required this.images,
    required this.currentPrice,
    required this.bidCount,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.lastBidder,
    this.increment,
    this.rounds,
    this.prizes = const [],
  });

  factory AuctionSummary.fromJson(Map<String, dynamic> j) => AuctionSummary(
        id: j['id'] as String,
        title: j['title'] as String,
        images: (j['images'] as List? ?? const []).cast<String>(),
        currentPrice: j['currentPrice'] as int,
        bidCount: (j['bidCount'] ?? 0) as int,
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        status: j['status'] as String,
        lastBidder: j['lastBidder'] == null
            ? null
            : Bidder.fromJson(j['lastBidder'] as Map<String, dynamic>),
        increment: j['increment'] as int?,
        rounds: parseRounds(j['rounds']),
        prizes: parsePrizes(j['prizes']),
      );

  /// Realtime event ирэхэд өөрчлөгдөх талбаруудыг л шинэчилнэ.
  AuctionSummary copyWith({
    int? currentPrice,
    int? bidCount,
    DateTime? endsAt,
    Bidder? lastBidder,
    String? status,
  }) =>
      AuctionSummary(
        id: id,
        title: title,
        images: images,
        currentPrice: currentPrice ?? this.currentPrice,
        bidCount: bidCount ?? this.bidCount,
        startsAt: startsAt,
        endsAt: endsAt ?? this.endsAt,
        status: status ?? this.status,
        lastBidder: lastBidder ?? this.lastBidder,
        increment: increment,
        rounds: rounds,
        prizes: prizes,
      );
}

class BidItem {
  final String id;
  final int price;
  final DateTime createdAt;
  final Bidder user;

  BidItem(
      {required this.id,
      required this.price,
      required this.createdAt,
      required this.user});

  factory BidItem.fromJson(Map<String, dynamic> j) => BidItem(
        id: j['id'] as String,
        price: j['price'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        user: Bidder.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class AuctionDetail {
  final String id;
  final String title;
  final String description;
  final List<String> images;
  final int currentPrice;
  final int increment;
  final int bidCount;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final Bidder? lastBidder;
  final List<BidItem> bids;
  final int serverTime;
  // Soft-close тохиргоо: сүүлийн softCloseSec секундэд үнэ ирвэл endsAt-г
  // extendSec секундээр сунгана (hardCloseAt-аас хэтрэхгүй).
  final int softCloseSec;
  final int extendSec;
  final DateTime? hardCloseAt;

  /// Санамсаргүй хаалтын цонхны урт (сек; 0 = идэвхгүй) ба цонх эхлэх агшин.
  /// Бодит хаагдах агшин нууц тул клиентэд ирдэггүй.
  final int randomCloseSec;
  final DateTime? randomCloseFrom;

  /// Шатуудын хуваарь (байхгүй бол null — хуучин soft-close дүрэм).
  final List<AuctionRound>? rounds;

  /// Нэмэлт шагналууд (2-р, 3-р байр); байхгүй бол хоосон.
  final List<AuctionPrize> prizes;

  /// Дууссан дуудлагын байрууд (байхгүй бол хоосон).
  final List<AuctionPlacement> placements;

  AuctionDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.images,
    required this.currentPrice,
    required this.increment,
    required this.bidCount,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.lastBidder,
    required this.bids,
    required this.serverTime,
    this.softCloseSec = 0,
    this.extendSec = 0,
    this.hardCloseAt,
    this.randomCloseSec = 0,
    this.randomCloseFrom,
    this.rounds,
    this.prizes = const [],
    this.placements = const [],
  });

  factory AuctionDetail.fromJson(Map<String, dynamic> j) => AuctionDetail(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        images: (j['images'] as List? ?? const []).cast<String>(),
        currentPrice: j['currentPrice'] as int,
        increment: j['increment'] as int,
        bidCount: (j['bidCount'] ?? 0) as int,
        startsAt: DateTime.parse(j['startsAt'] as String),
        endsAt: DateTime.parse(j['endsAt'] as String),
        status: j['status'] as String,
        lastBidder: j['lastBidder'] == null
            ? null
            : Bidder.fromJson(j['lastBidder'] as Map<String, dynamic>),
        bids: (j['bids'] as List? ?? const [])
            .map((b) => BidItem.fromJson(b as Map<String, dynamic>))
            .toList(),
        serverTime:
            (j['serverTime'] ?? DateTime.now().millisecondsSinceEpoch) as int,
        softCloseSec: (j['softCloseSec'] ?? 0) as int,
        extendSec: (j['extendSec'] ?? 0) as int,
        hardCloseAt: j['hardCloseAt'] == null
            ? null
            : DateTime.parse(j['hardCloseAt'] as String),
        randomCloseSec: (j['randomCloseSec'] ?? 0) as int,
        randomCloseFrom: j['randomCloseFrom'] == null
            ? null
            : DateTime.parse(j['randomCloseFrom'] as String),
        rounds: parseRounds(j['rounds']),
        prizes: parsePrizes(j['prizes']),
        placements: parsePlacements(j['placements']),
      );

  AuctionDetail copyWith({
    int? currentPrice,
    int? bidCount,
    DateTime? endsAt,
    String? status,
    Bidder? lastBidder,
    List<BidItem>? bids,
    int? randomCloseSec,
    DateTime? randomCloseFrom,
  }) =>
      AuctionDetail(
        id: id,
        title: title,
        description: description,
        images: images,
        currentPrice: currentPrice ?? this.currentPrice,
        increment: increment,
        bidCount: bidCount ?? this.bidCount,
        startsAt: startsAt,
        endsAt: endsAt ?? this.endsAt,
        status: status ?? this.status,
        lastBidder: lastBidder ?? this.lastBidder,
        bids: bids ?? this.bids,
        serverTime: serverTime,
        softCloseSec: softCloseSec,
        extendSec: extendSec,
        hardCloseAt: hardCloseAt,
        randomCloseSec: randomCloseSec ?? this.randomCloseSec,
        randomCloseFrom: randomCloseFrom ?? this.randomCloseFrom,
        rounds: rounds,
        prizes: prizes,
        placements: placements,
      );
}

class TokenPackage {
  final String id;
  final int tokens;
  final int priceMnt;

  TokenPackage(
      {required this.id, required this.tokens, required this.priceMnt});

  factory TokenPackage.fromJson(Map<String, dynamic> j) => TokenPackage(
        id: j['id'] as String,
        tokens: j['tokens'] as int,
        priceMnt: j['priceMnt'] as int,
      );
}

class WalletTx {
  final String id;
  final int amount;
  final String type;
  final String? note;
  final DateTime createdAt;

  WalletTx({
    required this.id,
    required this.amount,
    required this.type,
    this.note,
    required this.createdAt,
  });

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        amount: j['amount'] as int,
        type: j['type'] as String,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class TopupInvoice {
  final String paymentId;
  final String invoiceId;
  final int amountMnt;
  final String? qrText;
  final String? qrImageUrl;
  final String? deeplink;

  TopupInvoice({
    required this.paymentId,
    required this.invoiceId,
    required this.amountMnt,
    this.qrText,
    this.qrImageUrl,
    this.deeplink,
  });

  factory TopupInvoice.fromJson(Map<String, dynamic> j) => TopupInvoice(
        paymentId: j['paymentId'] as String,
        invoiceId: j['invoiceId'] as String,
        amountMnt: j['amountMnt'] as int,
        qrText: j['qrText'] as String?,
        qrImageUrl: j['qrImageUrl'] as String?,
        deeplink: j['deeplink'] as String?,
      );
}

/// Санал хүсэлт. `id` нь backend-ийн enum утга — сервер лүү яг ийм байдлаар
/// илгээгдэнэ, `label` нь зөвхөн дэлгэцийн текст.
class FeedbackOption {
  const FeedbackOption(this.id, this.label);

  final String id;
  final String label;
}

abstract class FeedbackMeta {
  static const types = [
    FeedbackOption('bug', 'Алдаа'),
    FeedbackOption('idea', 'Санаа'),
    FeedbackOption('improvement', 'Сайжруулах зүйл'),
    FeedbackOption('complaint', 'Гомдол'),
    FeedbackOption('suggestion', 'Санал'),
    FeedbackOption('praise', 'Талархал'),
    FeedbackOption('other', 'Бусад'),
  ];

  static const categories = [
    FeedbackOption('design', 'Дүр төр'),
    FeedbackOption('ux', 'Ашиглахад ойлгомжтой эсэх'),
    FeedbackOption('performance', 'Ажиллах хурд'),
    FeedbackOption('reliability', 'Алдаа саатал'),
    FeedbackOption('usability', 'Хэрэглэхэд хялбар'),
    FeedbackOption('content', 'Мэдээлэл'),
    FeedbackOption('billing', 'Төлбөр'),
    FeedbackOption('general', 'Ерөнхий'),
  ];

  static const statuses = {
    'open': 'Хүлээгдэж байна',
    'reviewing': 'Хянагдаж байна',
    'resolved': 'Шийдвэрлэгдсэн',
    'closed': 'Дууссан',
  };

  static String typeLabel(String id) => types
      .firstWhere((t) => t.id == id,
          orElse: () => const FeedbackOption('', '—'))
      .label;

  static String categoryLabel(String id) => categories
      .firstWhere((c) => c.id == id,
          orElse: () => const FeedbackOption('', '—'))
      .label;

  static String statusLabel(String id) => statuses[id] ?? id;
}

class FeedbackItem {
  final String id;
  final String type;
  final String category;
  final String message;
  final String status;
  final String? adminNote;
  final DateTime createdAt;

  FeedbackItem({
    required this.id,
    required this.type,
    required this.category,
    required this.message,
    required this.status,
    this.adminNote,
    required this.createdAt,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: j['id'] as String,
        type: j['type'] as String,
        category: j['category'] as String,
        message: j['message'] as String,
        status: (j['status'] ?? 'open') as String,
        adminNote: j['adminNote'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class OrderItem {
  final String id;
  final String auctionId;
  final int finalPrice;
  final DateTime payDeadline;
  final String status;
  final String auctionTitle;
  final List<String> auctionImages;

  /// Шагналын захиалга бол байр (2/3), эс бөгөөс null.
  final int? prizePlace;
  final String? prizeTitle;

  OrderItem({
    required this.id,
    required this.auctionId,
    required this.finalPrice,
    required this.payDeadline,
    required this.status,
    required this.auctionTitle,
    required this.auctionImages,
    this.prizePlace,
    this.prizeTitle,
  });

  bool get isPrize => prizePlace != null;

  /// 0₮ захиалга төлбөр шаардахгүй.
  bool get needsPayment => status == 'pending' && finalPrice > 0;

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final auction = (j['auction'] ?? const {}) as Map<String, dynamic>;
    return OrderItem(
      id: j['id'] as String,
      auctionId: j['auctionId'] as String,
      finalPrice: j['finalPrice'] as int,
      payDeadline: DateTime.parse(j['payDeadline'] as String),
      status: j['status'] as String,
      auctionTitle: (auction['title'] ?? '') as String,
      auctionImages: (auction['images'] as List? ?? const []).cast<String>(),
      prizePlace: (j['prizePlace'] as num?)?.toInt(),
      prizeTitle: j['prizeTitle'] as String?,
    );
  }
}

/// Дуудлага худалдаа зохион байгуулах хүсэлт (UC-05).
class AuctionRequest {
  final String id;
  final String title;
  final String description;
  final String? category;
  final int? startPrice;
  final String? preferredDate;
  final String? otherInfo;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AuctionRequest({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.startPrice,
    this.preferredDate,
    this.otherInfo,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.updatedAt,
  });

  /// Төлөв → монгол шошго.
  static const statusLabels = {
    'draft': 'Ноорог',
    'pending': 'Хүлээгдэж байна',
    'reviewing': 'Хянагдаж байна',
    'info_requested': 'Мэдээлэл дутуу',
    'approved': 'Зөвшөөрөгдсөн',
    'rejected': 'Татгалзсан',
    'cancelled': 'Цуцлагдсан',
  };

  static String statusLabel(String s) => statusLabels[s] ?? s;

  /// Хэрэглэгч цуцалж болох төлвүүд.
  bool get canCancel =>
      status == 'draft' || status == 'pending' || status == 'info_requested';

  /// Хэрэглэгч засаж болох төлвүүд (backend: draft, info_requested).
  bool get canEdit => status == 'draft' || status == 'info_requested';

  factory AuctionRequest.fromJson(Map<String, dynamic> j) => AuctionRequest(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        category: j['category'] as String?,
        startPrice: (j['startPrice'] as num?)?.toInt(),
        preferredDate: j['preferredDate'] as String?,
        otherInfo: j['otherInfo'] as String?,
        status: (j['status'] ?? 'pending') as String,
        adminNote: j['adminNote'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
      );
}
