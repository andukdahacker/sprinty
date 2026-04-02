# Story 8.1: StoreKit 2 Subscription Integration

Status: done

## Story

As a user,
I want to upgrade to premium coaching through a simple in-app purchase,
So that I get deeper, more nuanced coaching powered by a more capable AI model.

## Acceptance Criteria

1. **Purchase flow initiation** — Given a free-tier user, when they choose to upgrade to premium, then the StoreKit 2 purchase flow initiates, and on successful purchase the subscription state updates, the app sends the transaction ID to the server via `POST /v1/auth/refresh` with `transactionId`, and the server validates with Apple and issues a new JWT with `tier: "premium"`.

2. **Subscription state management (NFR27)** — Given subscription state changes (purchase, renewal, cancellation, grace period), when these events occur, then StoreKit 2 handles each state correctly with server-side receipt validation, and the JWT tier field updates accordingly.

3. **Immediate tier reflection** — Given a successful subscription purchase, when the server issues a new JWT with `tier: "premium"`, then `AppState.tier` updates to `.premium` immediately, and subsequent API requests include the updated JWT with the premium tier claim. (Model routing based on tier is Story 8.2.)

4. **Graceful cancellation** — Given a user cancels their subscription, when the subscription period ends, then the tier reverts to free gracefully, and the coach tone remains warm (no punitive messaging, no "you've been downgraded").

5. **Receipt validation failure handling** — Given StoreKit receipt validation fails on the server, when the server cannot verify the transaction with Apple, then the user remains on their current tier (fail-open for existing subscribers), receipt validation retries on next app launch, and the error is logged server-side.

6. **Offline purchase resilience** — Given the user is in airplane mode during purchase, when the StoreKit purchase completes locally but server validation is unavailable, then the purchase is queued locally, validation occurs on next server connectivity, and the user sees no error (StoreKit 2 handles deferred transactions).

7. **Reinstall resilience** — Given a user reinstalls the app, when the app launches and finds the existing device UUID in Keychain, then it checks `Transaction.currentEntitlements` for existing subscriptions, includes the transaction ID in the register request, and the JWT comes back with the correct tier immediately.

## Tasks / Subtasks

- [x] Task 1: StoreKit Configuration and Product Definition (AC: #1, #2)
  - [x] 1.1 Create `Sprinty.storekit` StoreKit configuration file in `ios/` with auto-renewable subscription product (product ID: `com.ducdo.sprinty.premium.monthly`)
  - [x] 1.2 Create subscription group "Premium Coaching" with monthly subscription at a test price
  - [x] 1.3 Add StoreKit configuration to Xcode scheme via `project.yml` — add `storeKitConfiguration: Sprinty.storekit` under the Debug scheme's run options

- [x] Task 2: SubscriptionService — iOS StoreKit 2 Integration (AC: #1, #2, #6, #7)
  - [x] 2.1 Create `SubscriptionServiceProtocol.swift` in `ios/sprinty/Services/Subscription/`
  - [x] 2.2 Create `SubscriptionService.swift` implementing StoreKit 2 Product loading, purchase flow, and entitlement checking
  - [x] 2.3 Implement `Transaction.updates` listener — see "Concurrency Architecture" section below for Task lifecycle management
  - [x] 2.4 Implement `Transaction.currentEntitlements` check for reinstall resilience
  - [x] 2.5 Handle all purchase result states: `.success`, `.pending` (ask-to-buy), `.userCancelled`
  - [x] 2.6 On successful purchase/renewal, call AuthService to refresh JWT with transaction ID → server returns `tier: "premium"`
  - [x] 2.7 On subscription expiry/cancellation, call AuthService to refresh JWT → server returns `tier: "free"`

- [x] Task 3: AuthService Updates — Receipt Validation Flow (AC: #1, #5, #7)
  - [x] 3.1 Add optional `transactionId: UInt64?` field to `RegisterRequest` struct (line 93 of AuthService.swift). Swift's default Codable encodes nil as `null` — Go's `json.Decoder` ignores null fields, so no custom encoding needed.
  - [x] 3.2 Add `refreshTokenWithTransaction(_ transactionId: UInt64) async throws` method to `AuthServiceProtocol` and `AuthService`. This calls `POST /v1/auth/refresh` with a JSON body containing `transactionId`. Update all mock conformances of `AuthServiceProtocol`.
  - [x] 3.3 Update `AuthService.register()` (private method, line 55) to accept optional `transactionId` parameter. In `ensureAuthenticated()`, call `Transaction.currentEntitlements` directly (do NOT go through SubscriptionService — avoids circular dependency) and pass transaction ID if subscription found.
  - [x] 3.4 Update `AuthService.ensureAuthenticated()` to parse `tier` from the JWT payload after registration/refresh and return it (or set it on AppState via a callback/closure).

- [x] Task 4: Server-Side Receipt Validation (AC: #1, #2, #5)
  - [x] 4.1 Add Apple App Store Server API client in `server/appstore/client.go` — JWT-based authentication with Apple (ES256), transaction lookup endpoint
  - [x] 4.2 Update `RegisterHandler` signature to `RegisterHandler(jwtSecret string, appStoreClient *appstore.Client)`. Add gzip/deflate request body decompression (matching pattern in `ChatHandler` lines 22-36 of chat.go). Accept optional `transactionId`, validate with Apple if present, set tier to `"premium"` if valid or `"free"` if absent/invalid.
  - [x] 4.3 Update `RefreshHandler` signature to `RefreshHandler(jwtSecret string, appStoreClient *appstore.Client)`. Add JSON body decoding (currently reads no body). MUST handle both empty-body requests (existing behavior — use claims tier) AND body-with-transactionId requests (new behavior — validate and update tier). Add gzip/deflate decompression.
  - [x] 4.4 Implement validation logic: verify transaction's `productId` matches `com.ducdo.sprinty.premium.monthly`, check `expiresDate` is in future, check `revocationDate` is absent
  - [x] 4.5 Implement fail-open behavior: if Apple API is unreachable, keep current tier from JWT claims and log error with `slog.Warn`
  - [x] 4.6 Add config fields to `server/config/config.go`: `AppleKeyID`, `AppleIssuerID`, `AppleBundleID`, `ApplePrivateKey` (base64-encoded PEM). Optional in dev environment (StoreKit sandbox doesn't require server validation), required in staging/production.
  - [x] 4.7 Update `main.go` lines 64, 68 to pass `appStoreClient` to `RegisterHandler` and `RefreshHandler`
  - [x] 4.8 Update `docs/api-contract.md` — add optional `transactionId` to register request schema, add optional JSON body to refresh endpoint, document new tier value `"premium"`

- [x] Task 5: AppState and UI Tier Integration (AC: #3, #4)
  - [x] 5.1 Create `Tier` enum in `ios/sprinty/Core/Models/Tier.swift` (shared by AppState, AuthService, SubscriptionService)
  - [x] 5.2 Add `tier: Tier = .free` property to `AppState`
  - [x] 5.3 In `SprintyApp.bootstrap()`, parse `tier` from JWT after `ensureAuthenticated()` and set `appState.tier`. Note: AuthService is currently created as a local variable in `bootstrap()` (line 31) and dropped after use. To share it with SubscriptionService, promote AuthService to a `@State` property on SprintyApp OR pass it through the SwiftUI environment.
  - [x] 5.4 Wire `SubscriptionService` creation in SprintyApp after AuthService is available. SubscriptionService depends on AuthService (for server calls). Start `Transaction.updates` listener here — see Concurrency Architecture section below.

- [x] Task 6: Comprehensive Test Suite (AC: #1-#7)
  - [x] 6.1 Create `MockSubscriptionService` in `ios/Tests/Mocks/` — must be `@unchecked Sendable`
  - [x] 6.2 iOS unit tests: SubscriptionService purchase flow states, entitlement checking, transaction update handling
  - [x] 6.3 iOS unit tests: AuthService registration with transaction ID, tier parsing from JWT
  - [x] 6.4 Update `server/tests/handlers_test.go` `setupMux()` (lines 97-98) to pass `appStoreClient` (or mock) to `RegisterHandler` and `RefreshHandler`
  - [x] 6.5 Go unit tests: RegisterHandler with/without transaction ID, RefreshHandler with/without body
  - [x] 6.6 Go unit tests: Apple App Store API client with mock HTTP responses via `httptest.Server` (valid subscription, expired, revoked, invalid product ID)
  - [x] 6.7 Go unit tests: Fail-open behavior when Apple API is unreachable (timeout, network error)
  - [x] 6.8 Run full iOS test suite — all 669 tests pass with no regressions

## Dev Notes

### Architecture Compliance

- **Middleware chain order** is critical (already exists in main.go): `LoggingMiddleware(mux)` wraps all routes, `AuthMiddleware` on protected routes. Story 8.1 does NOT add tier middleware or guardrails middleware — those are Stories 8.2 and 8.3. This story only handles StoreKit purchase flow and JWT tier field population.
- **Server is authoritative for tier.** The JWT `tier` field is the single source of truth. iOS never determines tier locally except as a cached optimistic state from the JWT.
- **No feature gating in this story.** This story establishes subscription infrastructure only. Tier-based model routing (8.2) and soft guardrails (8.3) are separate stories.
- **This story builds infrastructure without a purchase UI trigger.** No paywall or upgrade UI exists yet (no UX spec for it). For testing, use Xcode's StoreKit Transaction Manager (Debug → StoreKit → Manage Transactions) to trigger purchases programmatically, or write test code that calls `SubscriptionService.purchase()` directly.

### Tier Value: `"premium"` (NOT `"paid"`)

The API contract (`docs/api-contract.md` line 60) defines tier values as `"free"` and `"premium"`. Use `"premium"` everywhere — the JWT `tier` field, the `Tier` Swift enum raw value, and Go code must all use `"premium"`. Do NOT use `"paid"`.

### Existing Code to Reuse — DO NOT Reinvent

- **`AuthService.swift`** (`ios/sprinty/Services/Networking/AuthService.swift`) — Already has `register()` (private, line 55), `refreshToken()`, `ensureAuthenticated()`, Keychain storage, JWT payload decoding (line 81). EXTEND this, don't create a parallel auth flow.
- **`AuthServiceProtocol`** (AuthService.swift lines 4-8) — Has 3 methods: `ensureAuthenticated()`, `getToken()`, `refreshToken()`. Adding `refreshTokenWithTransaction()` requires updating protocol AND all mock conformances. No MockAuthService exists currently — check if any test files create ad-hoc conformances.
- **`KeychainHelper`** — Already handles secure storage with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Use for subscription state caching if needed.
- **`server/auth/jwt.go`** — `Claims` struct already has `Tier string` field (line 13). `CreateToken()` already accepts a `tier` parameter (line 17). `RegisterHandler` currently hardcodes `"free"` (auth.go line 34) — update to conditionally set based on receipt validation.
- **`server/handlers/auth.go`** — `RegisterHandler(jwtSecret)` and `RefreshHandler(jwtSecret)` exist. Extend signatures to accept `appStoreClient`. Extend request structs. Do NOT create new endpoints.
- **`registerRequest` struct** (auth.go line 12-14) — Currently just `DeviceID string`. Add optional `TransactionID`.
- **`AppError` enum** (`ios/sprinty/Core/Errors/AppError.swift`) — Use existing error cases. Add `.subscriptionError(underlying: any Error)` if needed.
- **`APIClient`** (`ios/sprinty/Services/Networking/APIClient.swift`) — Use for all HTTP calls to server.
- **`Constants.swift`** — Add product ID and any subscription-related Keychain keys here.

### Dependency Architecture — Avoiding Circular Dependencies

SubscriptionService needs AuthService (to call server for JWT refresh). AuthService.register() needs StoreKit entitlements (to include transaction ID). **Solution: AuthService calls StoreKit 2 APIs directly for the entitlement check during registration — it does NOT depend on SubscriptionService.** The dependency is one-way: `SubscriptionService → AuthService`.

```
SubscriptionService ──depends on──▶ AuthService
AuthService ──calls directly──▶ Transaction.currentEntitlements (StoreKit 2 API)
```

### AuthService Lifecycle — DI Wiring

Currently in `SprintyApp.bootstrap()` (line 31), AuthService is created as a local variable and dropped after `ensureAuthenticated()`. **This must change.** Options:
1. **Recommended:** Store AuthService as a `@State` property on `SprintyApp` and pass it to `RootView` via `.environment()`. SubscriptionService is created in `bootstrap()` after AuthService, also stored as `@State`, and passed via environment.
2. Alternative: Create both in `RootView` alongside other services — but this breaks the bootstrap flow where auth must complete before UI renders.

### Concurrency Architecture — Transaction.updates Listener

`SWIFT_STRICT_CONCURRENCY: complete` is enabled. A `Sendable` class cannot store a mutable `Task` reference.

**Recommended approach:** Make `SubscriptionService` NOT `Sendable`. Instead, start and manage it from `SprintyApp` (which is `@MainActor`):

```swift
// In SprintyApp — start listener after bootstrap
@State private var subscriptionService: SubscriptionService?
@State private var transactionListenerTask: Task<Void, Never>?

// In bootstrap(), after auth succeeds:
let subService = SubscriptionService(authService: authService)
subscriptionService = subService
transactionListenerTask = Task {
    await subService.listenForTransactionUpdates()
}

// SubscriptionService itself — no Task storage needed
final class SubscriptionService: SubscriptionServiceProtocol {
    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        }
    }

    func purchase() async throws -> Transaction? {
        let products = try await Product.products(for: [Constants.premiumProductId])
        guard let product = products.first else { return nil }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return nil }
            try await authService.refreshTokenWithTransaction(transaction.id)
            await transaction.finish()
            return transaction
        case .pending:
            return nil  // Ask-to-buy — Transaction.updates will notify when approved
        case .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }

    func checkCurrentEntitlement() async -> UInt64? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Constants.premiumProductId {
                return transaction.id
            }
        }
        return nil
    }
}
```

### Gzip/Deflate Decompression — Pre-existing Bug Fix

`RegisterHandler` and `RefreshHandler` currently read `r.Body` directly without decompression (auth.go lines 23, 46). The `ChatHandler` (chat.go lines 22-36) correctly decompresses. iOS `APIClient` may send compressed bodies. **Add decompression to both auth handlers** matching the ChatHandler pattern:

```go
body := r.Body
if r.Header.Get("Content-Encoding") == "deflate" {
    body = flate.NewReader(r.Body)
    defer body.Close()
} else if r.Header.Get("Content-Encoding") == "gzip" {
    gr, err := gzip.NewReader(r.Body)
    if err != nil { /* handle */ }
    body = gr
    defer gr.Close()
}
```

### RefreshHandler — Backward-Compatible Body Handling

`RefreshHandler` currently reads no request body (auth.go line 44-60). When adding `transactionId` support, it must handle BOTH cases:

```go
// Try to decode body — if empty or no transactionId, use claims tier
var req refreshRequest
tier := claims.Tier  // default: keep existing tier
if r.ContentLength > 0 {
    if err := json.NewDecoder(body).Decode(&req); err == nil && req.TransactionID != nil {
        // Validate with Apple and determine tier
        validatedTier, err := appStoreClient.ValidateTransaction(*req.TransactionID)
        if err != nil {
            slog.Warn("appstore.validation_failed", "error", err, "transactionId", *req.TransactionID)
            // Fail-open: keep existing tier
        } else {
            tier = validatedTier
        }
    }
}
token, err := auth.CreateToken(jwtSecret, claims.DeviceID, tier, claims.UserID)
```

### Handler Signature Changes

Both handlers gain a dependency on AppStoreClient. Update signatures and main.go wiring:

```go
// Updated handler signatures
func RegisterHandler(jwtSecret string, appStoreClient *appstore.Client) http.HandlerFunc { ... }
func RefreshHandler(jwtSecret string, appStoreClient *appstore.Client) http.HandlerFunc { ... }

// main.go updates (lines 64, 68):
appStoreClient := appstore.NewClient(cfg.AppleKeyID, cfg.AppleIssuerID, cfg.AppleBundleID, cfg.ApplePrivateKey)
mux.HandleFunc("POST /v1/auth/register", handlers.RegisterHandler(cfg.JWTSecret, appStoreClient))
mux.Handle("POST /v1/auth/refresh", authMW(http.HandlerFunc(handlers.RefreshHandler(cfg.JWTSecret, appStoreClient))))
```

### Apple Credentials — Environment Configuration

The `APPLE_PRIVATE_KEY` env var contains a base64-encoded PEM private key (multi-line PEM content won't survive as a raw env var). Decode at startup in `config.Load()`:

```go
// In config.go
AppleKeyID     string  // APPLE_KEY_ID
AppleIssuerID  string  // APPLE_ISSUER_ID
AppleBundleID  string  // APPLE_BUNDLE_ID
ApplePrivateKey string // APPLE_PRIVATE_KEY (base64-encoded PEM)
```

These should be **optional in dev** (StoreKit sandbox testing doesn't require server-side Apple API calls), **required in staging/production** (following the existing pattern for `ANTHROPIC_API_KEY` in config.go lines 39-42). When absent in dev, `appStoreClient` can be nil, and handlers skip validation (always return `"free"` tier).

### Project Structure Notes

**New files to create:**
```
ios/sprinty/Services/Subscription/
├── SubscriptionServiceProtocol.swift   # Protocol for subscription operations
└── SubscriptionService.swift           # StoreKit 2 implementation

ios/sprinty/Core/Models/Tier.swift      # Tier enum shared across layers

ios/Sprinty.storekit                    # StoreKit configuration file for testing

server/appstore/
├── client.go                           # Apple App Store Server API client
└── client_test.go                      # Unit tests with httptest.Server mocks

ios/Tests/Mocks/
└── MockSubscriptionService.swift       # Test mock (@unchecked Sendable)
```

**Existing files to modify:**
```
ios/sprinty/Services/Networking/AuthService.swift    # Add transactionId to register, add refreshTokenWithTransaction(), update AuthServiceProtocol
ios/sprinty/App/SprintyApp.swift                     # Store AuthService & SubscriptionService as @State, start Transaction.updates listener
ios/sprinty/App/AppState.swift                       # Add tier: Tier property
ios/sprinty/Core/Utilities/Constants.swift            # Add premiumProductId constant
ios/project.yml                                       # Add storeKitConfiguration to scheme

server/handlers/auth.go                              # Extend RegisterHandler/RefreshHandler signatures, add transactionId, gzip decompression
server/config/config.go                              # Add Apple API credential fields
server/main.go                                       # Pass appStoreClient to handlers
server/.env.example                                  # Document new env vars
server/tests/handlers_test.go                        # Update setupMux() to pass appStoreClient mock
docs/api-contract.md                                 # Add transactionId to register/refresh schemas
```

**Do NOT create:**
- `server/middleware/tier.go` — That's Story 8.2
- `server/middleware/guardrails.go` — That's Story 8.3
- Any paywall or upgrade UI — No UX spec exists for this yet

**Source files auto-included:** XcodeGen `project.yml` uses `sources: [{path: sprinty}]` (line 37) which auto-discovers all Swift files under `sprinty/`. New files under `Services/Subscription/` and `Core/Models/` are automatically included — no manual file list entries needed. The only `project.yml` change is the StoreKit scheme configuration.

### Tier Enum

Create in `ios/sprinty/Core/Models/Tier.swift`:

```swift
enum Tier: String, Codable, Sendable {
    case free
    case premium
}
```

Raw values must match the JWT/API values exactly: `"free"` and `"premium"`.

### Go Patterns to Follow

```go
// Updated register request (auth.go)
type registerRequest struct {
    DeviceID      string  `json:"deviceId"`
    TransactionID *uint64 `json:"transactionId,omitempty"`
}

// New refresh request (auth.go) — previously had no body
type refreshRequest struct {
    TransactionID *uint64 `json:"transactionId,omitempty"`
}

// Apple App Store Server API client (server/appstore/client.go)
type Client struct {
    httpClient *http.Client
    keyID      string
    issuerID   string
    bundleID   string
    privateKey *ecdsa.PrivateKey
}

func (c *Client) ValidateTransaction(transactionID uint64) (string, error) {
    // Returns tier string: "premium" if valid active subscription, "free" otherwise
    // Uses App Store Server API v2: GET /inApps/v1/transactions/{transactionId}
}
```

### Testing Standards

- **Swift Testing framework** — `import Testing`, `@Suite`, `@Test`, `#expect()`. NEVER XCTest.
- **Mocks** must be `@unchecked Sendable`
- **Go tests** co-located with source as `_test.go` files (except integration tests in `server/tests/`)
- **Go test naming**: `TestHandlerName_Condition_Expected`
- Test both success and error paths for every AC
- Use StoreKit Configuration file + Xcode's Transaction Manager for manual testing
- Mock Apple App Store Server API responses in Go tests using `httptest.Server`
- `auth-register-response.json` test fixture does NOT change (response shape is unchanged — still just `{token: "..."}`)
- Final verification: run full iOS test suite (650+ tests) and all Go tests

### Previous Story Intelligence (Story 7.3)

- **Pattern**: Services follow protocol-based DI. Create protocol first, then implementation.
- **Testing**: Story 7.3 created 23 iOS tests + 3 Go tests. Similar scope expected here.
- **Migrations**: Current schema is v15. If any local subscription state caching is needed, use v16.
- **All 650+ iOS tests must continue passing** after changes.
- **Code review feedback from 7.3**: Watch for dead code branches — ensure all code paths are reachable.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic-8-Story-8.1]
- [Source: _bmad-output/planning-artifacts/architecture.md#Authentication-Security]
- [Source: _bmad-output/planning-artifacts/architecture.md#Monetization-Tier-Architecture]
- [Source: _bmad-output/planning-artifacts/architecture.md#Server-API-Contract]
- [Source: _bmad-output/planning-artifacts/prd.md#FR53-FR55-FR58]
- [Source: _bmad-output/planning-artifacts/prd.md#NFR27]
- [Source: _bmad-output/planning-artifacts/prd.md#Store-Compliance-3.1.2]
- [Source: docs/api-contract.md#POST-v1-auth-register]
- [Source: docs/api-contract.md#POST-v1-auth-refresh]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Task 1: Created `Sprinty.storekit` StoreKit configuration file with "Premium Coaching" subscription group and `com.ducdo.sprinty.premium.monthly` product. Added `storeKitConfiguration` to Debug scheme in `project.yml`.
- Task 2: Created `SubscriptionServiceProtocol` and `SubscriptionService` with StoreKit 2 `Product.products()` loading, `product.purchase()` flow handling all result states (success/pending/userCancelled), `Transaction.updates` listener for renewals/cancellations/revocations, and `Transaction.currentEntitlements` for reinstall resilience.
- Task 3: Extended `AuthServiceProtocol` with `refreshTokenWithTransaction(_:)`. Added `transactionId` to `RegisterRequest` and new `RefreshRequest` struct. `ensureAuthenticated()` now checks `Transaction.currentEntitlements` directly (one-way dependency). Added `tierFromCurrentToken()` for JWT tier parsing. Created `MockAuthService`.
- Task 4: Created `server/appstore/client.go` — Apple App Store Server API v2 client with ES256 JWT auth, transaction validation (product ID, expiry, revocation checks). Updated `RegisterHandler` and `RefreshHandler` with appStoreClient dependency, gzip/deflate decompression, and transactionId support. RefreshHandler handles both empty-body (preserve tier) and body-with-transactionId (validate and update tier). Fail-open: keeps existing tier on Apple API failure. Added Apple credential config fields (optional in dev). Updated `api-contract.md` and `.env.example`.
- Task 5: Created `Tier` enum (`free`/`premium`) with raw values matching API contract. Added `tier` to `AppState`. Promoted `AuthService` to `@State` in `SprintyApp`, wired `SubscriptionService` with `Transaction.updates` listener task, parse tier from JWT after auth.
- Task 6: Created `MockSubscriptionService` and `MockAuthService`. 19 new iOS tests (SubscriptionService, AuthService subscription integration, Tier enum). 8 new Go tests (appstore client: valid/expired/revoked/wrong product/unreachable/404; handler tests: register with/without transactionId, refresh with/without body, premium tier preservation, gzip/deflate compression). All 669 iOS tests pass. All Go tests pass.

### Code Review (AI) — 2026-04-02

**Reviewer:** Claude Opus 4.6 (adversarial code review)

**Issues found and fixed:**

1. **[HIGH] AC3 violation — AppState.tier never updated after mid-session purchase/renewal.** `appState.tier` was only set once during bootstrap. Added `onSubscriptionChange` callback to `SubscriptionService` that re-reads tier from JWT and updates `AppState.tier` after every purchase, renewal, cancellation, or revocation. Wired in `SprintyApp.bootstrap()`.

2. **[HIGH] Security — RefreshHandler auto-promoted to premium when appStoreClient was nil.** Any request with a `transactionId` got premium tier without validation when Apple credentials were missing. Removed dev-mode auto-promotion; now preserves existing tier from JWT claims (consistent with RegisterHandler and fail-open pattern). Updated test expectation.

3. **[MEDIUM] Resource leak — `decompressBody()` returned `io.Reader` without closing gzip/deflate readers.** Changed return type to `io.ReadCloser`, added `defer body.Close()` in both RegisterHandler and RefreshHandler callers.

**All Go tests pass after fixes.**

### Change Log

- 2026-04-02: Code review fixes — immediate tier reflection (H1), RefreshHandler security fix (H2), decompressBody resource leak (M1)
- 2026-04-01: Story 8.1 implementation complete — StoreKit 2 subscription integration with server-side receipt validation

### File List

**New files:**
- `ios/Sprinty.storekit` — StoreKit configuration file for testing
- `ios/sprinty/Services/Subscription/SubscriptionServiceProtocol.swift` — Protocol for subscription operations
- `ios/sprinty/Services/Subscription/SubscriptionService.swift` — StoreKit 2 implementation
- `ios/sprinty/Core/Models/Tier.swift` — Tier enum shared across layers
- `server/appstore/client.go` — Apple App Store Server API client
- `server/appstore/client_test.go` — Unit tests with httptest.Server mocks
- `ios/Tests/Mocks/MockSubscriptionService.swift` — Test mock
- `ios/Tests/Mocks/MockAuthService.swift` — Test mock
- `ios/Tests/Services/SubscriptionServiceTests.swift` — iOS unit tests for Story 8.1

**Modified files:**
- `ios/sprinty/Services/Networking/AuthService.swift` — Added transactionId to RegisterRequest, refreshTokenWithTransaction(), currentEntitlementTransactionId(), tierFromCurrentToken()
- `ios/sprinty/App/SprintyApp.swift` — Promoted AuthService to @State, wired SubscriptionService, Transaction.updates listener
- `ios/sprinty/App/AppState.swift` — Added tier: Tier property
- `ios/sprinty/Core/Utilities/Constants.swift` — Added premiumProductId constant
- `ios/project.yml` — Added storeKitConfiguration to Debug scheme
- `server/handlers/auth.go` — Extended RegisterHandler/RefreshHandler signatures, transactionId, gzip decompression
- `server/config/config.go` — Added Apple API credential fields
- `server/main.go` — Pass appStoreClient to handlers
- `server/.env.example` — Documented new Apple env vars
- `server/tests/handlers_test.go` — Updated setupMux(), added Story 8.1 handler tests
- `docs/api-contract.md` — Added transactionId to register/refresh schemas
