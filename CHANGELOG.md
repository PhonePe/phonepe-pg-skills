# Changelog

All notable changes to the PhonePe PG Skills are documented in this file.

## [1.3.1]

### Added
- **phonepe-pg-skill/standardCheckoutAutoPay/standard_checkout_auto_pay_skill.md**: New Standard Checkout AutoPay skill
  - `AUTOPAY_SC_SETUP` — Subscription mandate setup via Standard Checkout endpoint (`/checkout/v2/pay`) with `SUBSCRIPTION_SETUP` flow; returns `redirectUrl` to PhonePe's hosted page
  - Documents full integration: setup → JS SDK launch → callback → Notify → Redeem cycle
  - Comparison table: Standard Checkout AutoPay vs Custom Checkout AutoPay

### Changed
- **phonepe-pg-skill/customCheckoutAutoPay/**: Renamed from `autoPay/`; contains `custom_checkout_auto_pay_skill.md` (Custom Checkout API-based mandate setup via UPI_INTENT/UPI_COLLECT)
- **phonepe-pg-skill/standardCheckoutAutoPay/**: New folder for hosted-page mandate setup
- **phonepe-pg-skill/SKILL.md**: Updated section 4 to document both AutoPay variants (4a Standard Checkout, 4b Custom Checkout)
- **README.md**: Clarified AutoPay supports both Standard and Custom Checkout integration types

## [1.3.0]

### Added
- **phonepe-pg-skill/customCheckoutIntegration/custom_checkout_integration_skill.md**: New Custom Checkout one-time payment skill
  - `CUSTOM_CHECKOUT_PAY` — Initiates payment with 6 payment modes: UPI_INTENT, UPI_COLLECT, UPI_QR, NET_BANKING, CARD, TOKEN
  - `CUSTOM_CHECKOUT_ORDER_STATUS` — Checks order-level payment status
  - `CUSTOM_CHECKOUT_TRANSACTION_STATUS` — Checks specific transaction attempt status
  - PCI endpoint routing for CARD and TOKEN payment modes
  - Device context requirements for UPI_INTENT (iOS vs Android differences)
  - Full field tables with required/optional indicators and constraints

- **phonepe-pg-skill/autoPay/auto_pay_skill.md**: New AutoPay / Subscription recurring payments skill
  - `AUTOPAY_SETUP` — Subscription mandate setup with PENNY_DROP or TRANSACTION auth workflows
  - `AUTOPAY_NOTIFY` — Pre-cycle notification before each billing deduction
  - `AUTOPAY_REDEEM` — Executes the actual deduction for a billing cycle
  - `AUTOPAY_SUBSCRIPTION_STATUS` — Checks mandate health including pause dates
  - `AUTOPAY_ORDER_STATUS` — Checks status of specific setup or redemption orders
  - `AUTOPAY_CANCEL` — Permanent subscription cancellation
  - Frequency reference table (DAILY through ON_DEMAND)
  - Retry & error strategy for failed redemptions
  - End-to-end lifecycle flow documentation

### Updated
- **phonepe-pg-skill/SKILL.md**: Added AutoPay and Custom Checkout skill references; expanded `When to Apply` triggers to include custom checkout and subscription scenarios
- **README.md**: Added Custom Checkout and AutoPay to Available Skills section

## [1.2.0]

### Added
- **standard_checkout_integration_skill.md**: New `LAUNCH_PAYMENT_PAGE` skill
  - Documents the PhonePe JS SDK (`checkout.js`) as the **required** method to launch the payment page
  - Explains why direct URL navigation fails (referrer header validation by PhonePe)
  - Sandbox vs Production script URL table
  - IFrame mode (recommended) with full callback implementation example
  - Redirect mode for simple tab-based flows
  - Callback response reference table: `USER_CANCEL` and `CONCLUDED` with required actions
  - `closePage()` documented as exceptional-use only
  - Flutter Web integration guide (JS bridge + Dart interop pattern)
  - AI Implementation Checklist including mandatory merchant notification about SDK requirement

### Fixed
- **SKILL.md**: Refined `When to Apply` triggers — more specific, actionable, includes exact error codes
  (`AUTHORIZATION_FAILED`, `INVALID_TRANSACTION_ID`) for stronger AI trigger matching; added "or refreshing"
  to auth trigger; added "handling payment callbacks"; added sandbox/production switching trigger
- **standard_checkout_integration_skill.md**: Removed incorrect idempotency claim —
  `merchantOrderId` reuse **fails** with `INVALID_MERCHANT_ORDER_ID` (HTTP 417); it is not idempotent
- **standard_checkout_integration_skill.md**: Removed prescriptive "Recommended ID format" —
  ID format is merchant-specific; only API-level constraints (`max 63 chars, alphanumeric/_/-`) are documented
- **standard_checkout_integration_skill.md**: Fixed network timeout retry guidance — now advises checking
  via `CHECK_PAYMENT_STATUS` before retrying, not blindly reusing the same `merchantOrderId`
- **standard_checkout_integration_skill.md**: Fixed Edge Cases table — duplicate `merchantOrderId` now
  correctly states PhonePe returns `INVALID_MERCHANT_ORDER_ID` (not "returns the original order")
- **standard_checkout_integration_skill.md**: Updated `INITIATE_STANDARD_CHECKOUT_PAYMENT` execution flow
  and checklist to reference `LAUNCH_PAYMENT_PAGE` as the required next step
- **standard_checkout_integration_skill.md**: Updated end-to-end integration flow to include JS SDK step
- **setup.sh**: Fixed `curl -fsSL ... | bash` — all `read` commands now use `/dev/tty` via `tty_read()`
  helper so user input works when stdin is a pipe
- **setup.sh**: Fixed wrong installation folder — when running from the cloned repo (`IS_CLONED=true`),
  pressing Enter no longer defaults to the source repo directory; a non-empty distinct path is required
- **setup.sh**: Fixed source repo cleanup — after installation from a cloned repo, the script prints
  the exact `rm -rf` command to remove the now-unneeded clone

## [1.1.0]

### Added
- **SKILL.md**: Full AI readiness rewrite for Auth and Refund skills
  - Numbered execution flows for all skills
  - Field tables with Required/Optional indicators and validation rules
  - AI Implementation Checklists for each skill
  - Structured error handling tables
  - Refund state table covering PENDING, COMPLETED, and FAILED states
- **standard_checkout_integration_skill.md**: New sections
  - Retry Strategy guide with `merchantOrderId` uniqueness rules and API error backoff table
  - Webhook / Server Callback Verification documentation
  - Edge Cases & Common Integration Errors reference table
- **CHANGELOG.md**: This file — version tracking for skill updates

### Fixed
- **SKILL.md**: Clarified that OAuth API paths differ between Sandbox and Production
- **SKILL.md**: Removed non-existent AutoPay references from `When to Apply` and skill description
- **SKILL.md**: Standardized Authorization header to `Authorization: O-Bearer <access_token>`
- **standard_checkout_integration_skill.md**: Broken anchor link on `CHECK_PAYMENT_STATUS` dependency
  (`#skill-auth-generate` → `#1-authentication-skill-base`)
- **standard_checkout_integration_skill.md**: Invalid JSON fragments in `paymentModeConfig` examples
  (added missing outer `{}` braces)
- **standard_checkout_integration_skill.md**: Removed incorrect `SKILL_PAYMENT_REFUND` dependency from
  `INITIATE_STANDARD_CHECKOUT_PAYMENT` (Refund is a related skill, not a dependency)
- **setup.sh**: `cp -r` nesting bug — re-running setup no longer creates `phonepe-pg-skill/phonepe-pg-skill/`
- **setup.sh**: `git clone 2>/dev/null` replaced with real error output for easier debugging
- **setup.sh**: Added 60-second timeout on `git clone` to prevent indefinite hangs
- **setup.sh**: Added input validation loop in `select_setup_type` — invalid input prompts again instead of exiting
- **README.md**: Added `CHECK_PAYMENT_STATUS` skill to the Available Skills section
- **README.md**: Removed `AutoPay (coming soon)` entry

## [1.0.0]

### Added
- Initial release of PhonePe PG Skills
- Authentication skill (`SKILL_AUTH_GENERATE`)
- Standard Checkout payment initiation skill (`INITIATE_STANDARD_CHECKOUT_PAYMENT`)
- Payment status check skill (`CHECK_PAYMENT_STATUS`)
- Refund skill (`SKILL_PAYMENT_REFUND`)
- Automated setup script (`setup.sh`)

### Added
- **SKILL.md**: Full AI readiness rewrite for Auth and Refund skills
  - Numbered execution flows for all skills
  - Field tables with Required/Optional indicators and validation rules
  - AI Implementation Checklists for each skill
  - Structured error handling tables
  - Refund state table covering PENDING, COMPLETED, and FAILED states
- **standard_checkout_integration_skill.md**: New sections
  - Idempotency & Retry Strategy guide with rules and backoff table
  - Webhook / Server Callback Verification documentation
  - Edge Cases & Common Integration Errors reference table
- **CHANGELOG.md**: This file — version tracking for skill updates

### Fixed
- **SKILL.md**: Clarified that OAuth API paths differ between Sandbox and Production
- **SKILL.md**: Removed non-existent AutoPay references from `When to Apply` and skill description
- **SKILL.md**: Standardized Authorization header to `Authorization: O-Bearer <access_token>`
- **standard_checkout_integration_skill.md**: Broken anchor link on `CHECK_PAYMENT_STATUS` dependency
  (`#skill-auth-generate` → `#1-authentication-skill-base`)
- **standard_checkout_integration_skill.md**: Invalid JSON fragments in `paymentModeConfig` examples
  (added missing outer `{}` braces)
- **standard_checkout_integration_skill.md**: Removed incorrect `SKILL_PAYMENT_REFUND` dependency from
  `INITIATE_STANDARD_CHECKOUT_PAYMENT` (Refund is a related skill, not a dependency)
- **setup.sh**: `cp -r` nesting bug — re-running setup no longer creates `phonepe-pg-skill/phonepe-pg-skill/`
- **setup.sh**: `git clone 2>/dev/null` replaced with real error output for easier debugging
- **setup.sh**: Added 60-second timeout on `git clone` to prevent indefinite hangs
- **setup.sh**: Added input validation loop in `select_setup_type` — invalid input prompts again instead of exiting
- **README.md**: Added `CHECK_PAYMENT_STATUS` skill to the Available Skills section
- **README.md**: Removed `AutoPay (coming soon)` entry

## [1.0.0]

### Added
- Initial release of PhonePe PG Skills
- Authentication skill (`SKILL_AUTH_GENERATE`)
- Standard Checkout payment initiation skill (`INITIATE_STANDARD_CHECKOUT_PAYMENT`)
- Payment status check skill (`CHECK_PAYMENT_STATUS`)
- Refund skill (`SKILL_PAYMENT_REFUND`)
- Automated setup script (`setup.sh`)
