# Latent Dual-Track Runbook (MAS + Direct)

Date: 2026-02-26

## Scope Implemented in Code

- Dual targets/schemes:
  - `rawctl` (Direct)
  - `rawctl-mas` (MAS)
- Distribution channel gates:
  - `DISTRIBUTION_CHANNEL_DIRECT`
  - `DISTRIBUTION_CHANNEL_MAS`
- Update channel split:
  - Direct uses Sparkle.
  - MAS has no Sparkle and uses App Store updates only.
- Billing abstraction:
  - `BillingProvider` with `DirectBillingProvider` and `StoreKitBillingProvider`.
  - Direct uses web checkout.
  - MAS uses StoreKit purchase/restore and App Store subscription management.
- MAS billing compliance UX:
  - No external checkout in MAS flow (`AccountError.externalCheckoutNotAllowed` guard).
  - `Restore Purchases` entry added in account UI.
- Authentication compliance UX:
  - Sign in with Apple added to sign-in screen.
  - Email magic link + Google kept.
- Account deletion:
  - In-app delete flow (`DeleteAccountView`) with re-auth code + explicit confirmation.
  - Local deletion-request timestamp recorded for audit.
- Legal links:
  - Privacy/Terms/Support links on sign-in and plans/checkout views.
- MAS compliance automation:
  - `scripts/verify-mas-compliance.sh` validates:
    - MAS compile flag
    - MAS Info.plist key hygiene (`SU*` absent)
    - built bundle does not embed/link Sparkle

## CI/CD

- Direct release workflow:
  - `.github/workflows/release-direct.yml`
- MAS release workflow:
  - `.github/workflows/release-mas.yml`
  - includes `./scripts/verify-mas-compliance.sh`
- MAS export options:
  - `exportOptions-mas.plist`

## Verified Locally

- `xcodebuild -scheme rawctl ... build` succeeded.
- `xcodebuild -scheme rawctl-mas ... build` succeeded.
- `./scripts/verify-mas-compliance.sh` passed.
- `build-for-testing` succeeded for test targets.

## Manual App Store Connect Steps (Required)

1. Create MAS app record for bundle ID `Shacoworkshop.latent.mas`.
2. Enable and configure Sign in with Apple capability for MAS App ID.
3. Create IAP products (exact IDs must match app config):
   - `com.latent.pro.monthly`
   - `com.latent.pro.yearly`
   - `com.latent.credits.100`
   - `com.latent.credits.300`
   - `com.latent.credits.1000`
4. Configure subscription group, tiers, locales, review screenshots, and metadata.
5. Set URLs:
   - Support URL
   - Privacy URL
   - Terms URL
6. Fill App Privacy nutrition labels.
7. Provide review notes:
   - test account
   - purchase path
   - restore path
   - account deletion path
8. Set App Store Server API credentials on backend and enable transaction verification endpoint:
   - `/billing/app-store/sync`

## Backend Follow-up (Required for Production)

1. Finalize `/billing/app-store/sync` payload contract:
   - currently receives base64 `transaction.jsonRepresentation` list.
2. Confirm account deletion endpoint:
   - primary: `/user/delete`
   - fallback: `/user/account/delete`
3. Confirm deletion-code semantics for:
   - `/auth/magic-link` with `purpose = account_deletion`

## Release Cadence Recommendation

- MAS: low-frequency stability releases, every 3-6 months minimum.
- Direct: high-frequency iteration with Sparkle updates.
- Keep shared core logic in sync; gate channel-specific behavior via `AppDistributionChannel`.
