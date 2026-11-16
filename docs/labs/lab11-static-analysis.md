# Лаб 11 — Static analysis ба эмзэг байдлын илрүүлэлт

## 1. Хэрэгслүүд ба сонголтын шалтгаан

| Зориулалт | Хэрэгсэл | Яагаад |
|---|---|---|
| Java linter | PMD 7 (`maven-pmd-plugin` 3.28.0) | Maven-д шууд нэгддэг, bestpractices/errorprone/security ангиллаар бодит алдаа олдог, `pmd:check` build-ийг унагадаг |
| Flutter linter | `flutter analyze` (`flutter_lints` + нэмэлт дүрэм) | Dart-ийн стандарт хэрэгсэл |
| Dependency scan | OSV-Scanner 2.7.1 (`pom.xml`, `pubspec.lock`) | Хурдан (NVD татах шаардлагагүй), Maven + pub хоёуланг дэмжинэ, GitHub Action бий |
| Автомат шинэчлэл | Dependabot | maven / pub / github-actions, долоо хоног тутам |

Дүрмийн багц: [backend-spring/pmd-ruleset.xml](../../backend-spring/pmd-ruleset.xml) — стилийн (формат) дүрмийг оруулаагүй, зөвхөн ашиглагдаагүй код, алдаанд өртөмтгий хэв маяг, аюулгүй байдал.

Тэмдэглэл: PMD нь JDK 27 дээр parse алдаа өгдөг (ClassStub parsing failed), тиймээс JDK 17 (төслийн target ба CI-ийн хувилбар) дээр ажиллуулна.

```bash
cd backend-spring && mvn pmd:check          # JDK 17
cd app && flutter analyze
osv-scanner scan source -L backend-spring/pom.xml -L app/pubspec.lock --config=osv-scanner.toml
```

## 2. Linter — өмнө / хойно

### Java (PMD): 9 -> 0 ([өмнө](lab11/pmd-before.txt), [хойно](lab11/pmd-after.txt))

| Дүрэм | Өмнө | Хойно | Арга |
|---|---|---|---|
| LiteralsFirstInComparisons | 2 | 0 | `"PAID".equals(status)` — null-safe болгов |
| UseLocaleWithCaseConversions | 1 | 0 | `toUpperCase(Locale.ROOT)` (Turkish locale-ийн алдаанаас сэргийлнэ) |
| UnnecessaryFullyQualifiedName | 1 | 0 | `java.util.Map` -> `Map` (import байгаа) |
| MissingStaticMethodInNonInstantiatableClass | 1 | 0 | False positive (nested annotation-ы контейнер) — `@SuppressWarnings` + тайлбар |
| AvoidUsingHardCodedIP | 1 | 0 | `0.0.0.0` bind зориудаар — `NOPMD` + тайлбар |
| DoNotTerminateVM | 1 | 0 | Seed нь нэг удаагийн CLI — `NOPMD` + тайлбар |
| SystemPrintln | 2 | 0 | k6 скрипт stdout-оос уншдаг — `NOPMD` + тайлбар |
| **Нийт** | **9** | **0** | 4 бодит засвар (4 зөрчил), 5 зорилтот suppression |

### Flutter: 2 -> 0 ([өмнө](lab11/flutter-before.txt), [хойно](lab11/flutter-after.txt))
`analysis_options.yaml`-д `prefer_single_quotes`, `always_declare_return_types`, `avoid_print`, `unawaited_futures`, `use_build_context_synchronously`, `prefer_final_locals`, `cancel_subscriptions`, `close_sinks` нэмсэн. Олдсон 2 зөрчил:
- `unawaited_futures` — `auction_detail_screen.dart` `refreshProfile()` -> `unawaited(...)` (зан төлөв өөрчлөгдөхгүй)
- `prefer_final_locals` — `Widget tile` -> `final Widget tile`

## 3. Dependency scan ([өмнө](lab11/osv-before.txt), [хойно](lab11/osv-after.txt))

Өмнө: 13 багц, 49 эмзэг байдал — 10 Critical, 17 High, 21 Medium, 1 Low. Хойно: 1 багц, 2 (Critical, ашиглагдах боломжгүй).

| Сан | Хуучин -> Шинэ | Хамгийн өндөр CVSS | Түвшин | Үйлдэл |
|---|---|---|---|---|
| bcprov-jdk18on | 1.80 -> 1.85 | 9.3 | Critical | Шинэчилсэн (`bcprov.version`) |
| tomcat-embed-core | 10.1.55 -> 10.1.59 | 9.8 | Critical | `tomcat.version` override |
| io.netty (codec, codec-http, http2, handler) | 4.1.135 -> 4.1.137 | 9.1 | Critical | `netty.version` override |
| jackson-core/databind | 2.21.4 -> 2.21.7 | 7.5 | High | `jackson-bom.version` override |
| postgresql | 42.7.11 -> 42.7.12 | 8.2 | High | `postgresql.version` override |
| snappy-java (kafka-clients-ээр) | 1.1.10.5 -> 1.1.10.9 | 7.5 | High | `dependencyManagement` |
| lz4-java | 1.10.1 -> 1.11.4 | 7.3 | High | `dependencyManagement` |
| log4j-api | 2.24.3 -> 2.25.5 | 6.3 | Medium | `log4j2.version` override |
| spring-webmvc (GHSA-j9f9-w8pj-32f8, GHSA-pc63-qcmh-9cmg) | 6.2.19 | 9.8 | Critical | **Шинэчлэх боломжгүй** — доор |

spring-webmvc: 6.2.x салбарын сүүлийн хувилбар 6.2.19, засвар зөвхөн Spring 7.0.9 (Spring Boot 4) дээр. Хоёр CVE нь SSE fragment rendering, XsltView-тэй холбоотой бөгөөд төсөл эдгээрийг ашигладаггүй (REST JSON) тул exploit хийх боломжгүй гэж үзэв. [osv-scanner.toml](../../osv-scanner.toml)-д тайлбартай, хугацаатай (2027-03-01) ignore хийсэн. Boot 4 руу шилжихэд дахин үнэлнэ.

Flutter (`pubspec.lock`) — мэдэгдэж буй эмзэг байдал олдсонгүй. `flutter pub outdated`-д зарим багц (go_router, riverpod г.м.) шинэ major-той боловч security асуудал биш тул хөндөөгүй.

## 4. CI ([ci.yml](../../.github/workflows/ci.yml))

- `backend`: `mvn -B pmd:check` (lint) -> `mvn -B test`
- `app`: `flutter analyze` -> `flutter test`
- `dependency-scan`: `google/osv-scanner-action` (`osv-scanner.toml`-той) — шинэ эмзэг байдал гарвал унана, тайлбартай ignore-той CVE-үүд CI-г улаан болгохгүй
- `.github/dependabot.yml`: maven (/backend-spring), pub (/app), github-actions (/) — weekly

## 5. Дэлгэцийн зураг
<!-- TODO: pmd:check амжилттай, osv-scanner өмнө/хойно, CI ногоон, Dependabot PR-ын зураг -->
