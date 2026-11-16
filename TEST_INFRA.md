# E2E Test Infra: Milk HUB (Indian Dairy Edition)

## Test Philosophy
- **Requirement-Driven & Opaque-Box**: Tests are derived directly from `ORIGINAL_REQUEST.md` (R1 through R5) and `PROJECT.md` acceptance criteria, verifying behavior as experienced by dairy owners, delivery boys, and household customers.
- **Methodology**: Systematic 4-tier testing hierarchy utilizing Category-Partition, Boundary Value Analysis (BVA), Pairwise Combinatorial Testing, and Realistic Operational Workload Simulations.
- **Zero-Network Isolation**: Pure in-memory repository adapters conforming to `PROJECT.md` interface contracts (`RouteRepository`, `PauseRepository`, `OfflineDeliveryQueueService`, `CustomerRepository`, `BillingRepository`) with Riverpod `ProviderScope(overrides: [ ... ])`. Zero live Supabase network dependencies ensure 100% deterministic, high-speed execution under standard `flutter test`.

---

## Feature Inventory & Test Coverage Matrix

| # | Feature / Requirement | Source | Tier 1 (Feature) | Tier 2 (Boundary) | Tier 3 (Cross-Feature) | Tier 4 (Real-World) | Total Tests |
|---|-----------------------|--------|:----------------:|:-----------------:|:----------------------:|:-------------------:|:-----------:|
| 1 | **R1: Bilingual Toggle & Hindi-First Accessibility** | ORIGINAL_REQUEST §R1 | 6 | 5 | 2 | 2 | 15 |
| 2 | **R2: Route Management & Customer Stop Sequencing** | ORIGINAL_REQUEST §R2 | 6 | 6 | 3 | 3 | 18 |
| 3 | **R3: High-Speed 1-Tap Delivery Sheet & Keep-Awake** | ORIGINAL_REQUEST §R3 | 6 | 6 | 3 | 3 | 18 |
| 4 | **R4: Indian Payments & Free WhatsApp Invoicing** | ORIGINAL_REQUEST §R4 | 6 | 6 | 2 | 2 | 16 |
| 5 | **R5: Customer Vacation / Pause Guardrails** | ORIGINAL_REQUEST §R5 | 6 | 6 | 2 | 2 | 16 |
| **Total** | **All 5 Core Requirement Areas** | | **30** | **29** | **8** | **5** | **72 Tests** |

*Note*: Every requirement strictly exceeds the threshold minimums of >=5 Tier 1, >=5 Tier 2, pairwise Tier 3, and >=5 Tier 4 scenarios.

---

## Test Architecture & Layout

### Test Directory Layout
```
test/
├── helpers/
│   ├── dairy_test_fixtures.dart            # Mock Indian dairy data fixtures (Sellers, Customers, Routes)
│   ├── in_memory_dairy_data_store.dart     # Central pure in-memory state engine
│   ├── in_memory_route_repository.dart     # RouteRepository implementation (PROJECT.md §1)
│   ├── in_memory_pause_repository.dart     # PauseRepository implementation (PROJECT.md §2)
│   ├── in_memory_offline_queue_service.dart# OfflineDeliveryQueueService implementation (PROJECT.md §3)
│   ├── in_memory_customer_repository.dart  # CustomerRepository implementation
│   ├── in_memory_billing_repository.dart   # BillingRepository implementation
│   └── dairy_e2e_test_harness.dart         # Harness wiring ProviderScope overrides & platform mocks
└── e2e/
    └── e2e_dairy_distribution_test.dart    # 4-Tier Opaque-Box Comprehensive Test Suite
```

### Execution Command
The full test suite executes headlessly in pure Dart VM via standard Flutter testing tooling:
```powershell
flutter test test/e2e/e2e_dairy_distribution_test.dart --reporter expanded
```
- **Exit Code**: 0 on full pass.
- **Execution Time**: ~2 to 5 seconds.
- **Dependencies**: Uses strictly existing `flutter_test` in `dev_dependencies`.

---

## Detailed Tier Specifications

### Tier 1: Feature Coverage (30 Tests)
- **R1 Bilingual Localization**:
  - `T1.1.1`: English to Hindi (`en` -> `hi`) runtime toggle.
  - `T1.1.2`: Hindi to English (`hi` -> `en`) runtime toggle.
  - `T1.1.3`: Persistence of locale preference across cold restarts in `SharedPreferences`.
  - `T1.1.4`: Exact vernacular phrases validation ("✔ दिया", "आज नहीं लिया", "दूध बंद (छुट्टी)").
  - `T1.1.5`: Indian dairy domain glossary translation parity (Cow, Buffalo, Mixed, Morning, Evening).
  - `T1.1.6`: Visual color code and minimum touch target size (48dp) accessibility invariance.
- **R2 Route Management & Sequencing**:
  - `T1.2.1`: Route creation and retrieval (`createRoute`, `getAllRoutes`, `getRoutesBySeller`).
  - `T1.2.2`: Customer stop sequence assignment `1..N`.
  - `T1.2.3`: Customer drag-and-drop reordering (`updateCustomerSequence`).
  - `T1.2.4`: Multi-shift route filtering (`morning`, `evening`, `both`).
  - `T1.2.5`: Unified Owner-Seller route execution access for solo doodhwalas.
  - `T1.2.6`: Stop sequence pill badge display (`[1]`, `[2]`, `[3]`).
- **R3 High-Speed Delivery Sheet**:
  - `T1.3.1`: 1-tap delivery marking (`[ ✔ दिया ]`) with default customer quota.
  - `T1.3.2`: Inline volume stepper increments (`+250ml`, `+500ml`, `+1L`) with `MilkUtils` integration.
  - `T1.3.3`: Inline volume stepper decrement (`-250ml`).
  - `T1.3.4`: 1-tap delivery skip action ("आज नहीं लिया") recording ₹0 billed.
  - `T1.3.5`: Offline delivery queue enqueue and automatic background sync.
  - `T1.3.6`: Screen keep-awake lifecycle contract (`WakelockPlus.enable()` on mount, `disable()` on unmount).
- **R4 Indian Payments & WhatsApp Invoicing**:
  - `T1.4.1`: NPCI UPI Intent URL generation (`upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...`).
  - `T1.4.2`: Static UPI QR code payload string formatting.
  - `T1.4.3`: Doorstep cash collection partial payment logging & bill recalculation.
  - `T1.4.4`: Doorstep cash collection full settlement transitioning bill status to `'paid'`.
  - `T1.4.5`: Bilingual WhatsApp invoice text generation with vernacular header and embedded UPI link.
  - `T1.4.6`: WhatsApp intent URL construction with Indian E.164 phone normalization (`919876543210`).
- **R5 Vacation / Pause Guardrails**:
  - `T1.5.1`: Customer submits future vacation pause date range with pending status.
  - `T1.5.2`: Guardrail verification: Unapproved (`pending`) pause does NOT stop deliveries.
  - `T1.5.3`: Seller review and approval lifecycle updating status to `'approved'`.
  - `T1.5.4`: Guardrail verification: Approved pause DOES stop deliveries (`isCustomerPausedOnDate` returns `true`).
  - `T1.5.5`: Automatic delivery resumption on the day following the pause end date.
  - `T1.5.6`: Seller rejection lifecycle updating status to `'rejected'`.

### Tier 2: Boundary & Corner Cases (29 Tests)
- **R1 Boundaries**:
  - `T2.1.1`: Cold boot with uninitialized storage falls back strictly to Hindi Devanagari (`hi`).
  - `T2.1.2`: Corrupted or unsupported locale codes fallback safely to `hi`.
  - `T2.1.3`: Rapid stress toggling (20 alternating cycles) resolves consistently without race condition.
  - `T2.1.4`: Parameterized localized strings format currency and volume cleanly.
  - `T2.1.5`: Missing translation keys fall back safely without uncaught runtime errors.
- **R2 Boundaries**:
  - `T2.2.1`: Empty route handling (0 customers) renders clean empty state without index crashes.
  - `T2.2.2`: Single customer route reordering is a safe no-op.
  - `T2.2.3`: Historical delivery and billing immutability: stop reordering never mutates past records.
  - `T2.2.4`: Route deletion safely unassigns customers (`ON DELETE SET NULL`) without orphan errors.
  - `T2.2.5`: Sequence collision normalization eliminates duplicate indices.
  - `T2.2.6`: Unassigned customers display neutral sequence badge (`[--]`).
- **R3 Boundaries**:
  - `T2.3.1`: Strict volume negative clamping at 0 mL (`-250ml` clamped at 0).
  - `T2.3.2`: Zero-volume delivery prevention rejects attempts to mark 0 mL as delivered.
  - `T2.3.3`: Large commercial volume arithmetic precision (150+ L @ ₹58.50/L without floating point drift).
  - `T2.3.4`: Rapid double-tap debouncing ensures idempotent single delivery record insertion.
  - `T2.3.5`: Offline queue persistence and durability across app cold restarts.
  - `T2.3.6`: Screen keep-awake suspension during app backgrounding (`paused` vs `resumed`).
- **R4 Boundaries**:
  - `T2.4.1`: Zero pending balance UPI handling formats clean `am=0.00` and disables payment button.
  - `T2.4.2`: Indian phone number sanitization across multiple formats (`+91`, spaces, hyphens, 10-digit).
  - `T2.4.3`: Devanagari script and special character URL encoding in UPI payee and note.
  - `T2.4.4`: Cash overpayment capping: payment exceeding bill total caps `paidAmount` and clamps `pendingAmount` to 0.
  - `T2.4.5`: NPCI two-decimal precision strictness (`50` -> `50.00`, `50.5` -> `50.50`).
  - `T2.4.6`: Missing seller UPI ID fallback in WhatsApp invoice replaces link with cash payment prompt.
- **R5 Boundaries**:
  - `T2.5.1`: Validation rejection of past start dates (yesterday).
  - `T2.5.2`: Validation rejection of inverted date ranges (`startDate > endDate`).
  - `T2.5.3`: Single-day pause (`startDate == endDate`) pauses only that single day.
  - `T2.5.4`: Overlapping pause collision detection.
  - `T2.5.5`: Full-day date boundary inclusivity (00:00:00 through 23:59:59).
  - `T2.5.6`: Multi-seller pending pause isolation prevents data leakage between sellers.

### Tier 3: Cross-Feature Pairwise Combinations (8 Tests)
- `T3.1`: Shift Filtering + Customer Sequence Ordering (`R2 + R2`).
- `T3.2`: Approved Vacation + 1-Tap Delivery / Volume Stepper Blocking (`R5 + R3`).
- `T3.3`: Doorstep Cash Collection + UPI URL Remainder & WhatsApp Invoice Balance (`R4 + R4`).
- `T3.4`: Bilingual Runtime Toggle + WhatsApp Invoice Generation (`R1 + R4`).
- `T3.5`: Stop Drag & Reordering + Historical Delivery Immutability (`R2 + R3`).
- `T3.6`: Offline Delivery Queue Sync + Automatic Monthly Bill Rollup (`R3 + R4`).
- `T3.7`: Pending Vacation Pause + 1-Tap Skip Action (`R5 + R3`).
- `T3.8`: Unified Owner-Seller Mode + Multi-Route Selection (`R2 + R2`).

### Tier 4: Real-World Daily Dairy Operational Scenarios (5 Scenarios)
- `T4.1`: **Scenario 1 - Full Morning Route Run**: Delivery boy completes morning route with 5 sequenced stops, volume adjustments, 1 skip, offline queue caching, network recovery auto-sync, and 100% completion.
- `T4.2`: **Scenario 2 - Mid-Route Customer Addition & Dynamic Reordering**: Owner adds new household mid-route, re-indexes delivery stops, and delivers in updated sequence without disrupting past records.
- `T4.3`: **Scenario 3 - Customer Vacation Lifecycle & Delivery Sheet Impact**: Customer submits pause, pending state leaves delivery active, seller approves pause, delivery is grayed out with "⛔ आज दूध बंद (छुट्टी)", and delivery automatically resumes after vacation ends.
- `T4.4`: **Scenario 4 - End-of-Month Billing Settlement**: Monthly bill computed, seller collects doorstep cash, system generates UPI deep link for remainder, and formats bilingual WhatsApp invoice with instant payment link.
- `T4.5`: **Scenario 5 - Dual-Shift & Multi-Route Operation in Unified Owner Mode**: Solo doodhwala switches between Morning and Evening routes and shifts seamlessly, logging all transactions accurately.

---

## Pass/Fail Quality Gates
1. `flutter analyze` passes with 0 errors and 0 warnings.
2. All 72 tests pass with 0 failures under `flutter test test/e2e/e2e_dairy_distribution_test.dart`.
3. Total test execution time is under 10 seconds.
4. Zero unhandled platform exceptions or uninitialized Supabase assertions.
