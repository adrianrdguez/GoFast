# Monetization

## Overview

GoFast uses a freemium model with a subscription tier (GoFast Pro). The core value—knowing when to leave for your flight—is always free. Pro unlocks convenience, control, and advanced features.

## Philosophy: Core Free, Pro Convenient

**Free tier solves the anxiety**: Every user can see when to leave for their next flight.
**Pro tier removes friction**: Power users get unlimited flights, multiple transport options, and customization.

This approach:
- Maximizes user base (low barrier to entry)
- Builds trust (core value is free)
- Creates natural upgrade path (free users hit limits, want more)
- Avoids paywall anxiety ("Will I miss my flight if I don't pay?")

## Feature Split: Free vs Pro

### Free Tier

**Flight Detection**:
- 1 active flight (the most imminent upcoming flight)
- Automatic detection from calendar
- 90-day look-ahead window

**Widget**:
- Small and medium widget sizes
- Single transport recommendation (best option only)
- Basic countdown timer
- Automatic refresh

**Transport**:
- Primary transport mode shown (auto-selected)
- Apple Maps, Uber, Grab deep-links
- Standard ETA calculation

**Timing**:
- Automatic buffer calculation
  - Domestic: 90 minutes + 15 min buffer
  - International: 180 minutes + 30 min buffer
- Single location (home only)

**Data**:
- Current location-based calculations
- Standard airport procedure times

### Pro Tier

**Flight Detection**:
- Unlimited active flights
- 365-day look-ahead
- Manual flight entry (post-MVP)
- Flight history view

**Widget**:
- Large widget size with transport comparison
- Multiple transport options displayed
- Custom widget refresh intervals
- Flight selection in widget (if multiple)

**Transport**:
- All transport modes visible (up to 3 in widget)
- Transport reliability scores
- Cost comparison
- Favorite transport modes

**Timing**:
- Customizable buffer times (0-60 minutes)
- Per-transport buffer settings
- Multiple saved locations (home, hotel, office)
- Location-aware suggestions ("Leaving from hotel?")

**Alerts** (Post-MVP):
- Smart notifications ("Leave in 15 minutes")
- Traffic delay warnings
- Flight status changes

**Advanced** (Post-MVP):
- Siri Shortcuts support
- Apple Watch complications
- Export/share departure times
- Family sharing (up to 5 members)

## Subscription Model

### Pricing Strategy

**Monthly**: $2.99 / €2.99 / £2.49
**Annual**: $19.99 / €19.99 / £17.99 (44% savings)
**Lifetime**: $49.99 / €49.99 / £44.99 (Post-MVP)

### Regional Pricing

- Tier 1 (US, EU, UK): Prices above
- Tier 2 (Japan, Singapore, Australia): +20%
- Tier 3 (Thailand, Malaysia, India): -30%
- Tier 4 (Other): Adjusted for purchasing power

### Free Trial

**14-day free trial** for annual subscription
- Full Pro features during trial
- No credit card required (if allowed by App Store policies)
- Clear trial expiration messaging
- Easy upgrade at trial end

## Paywall UX Rules

### 1. Non-Intrusive Placement

Paywalls appear only when:
- User attempts Pro action (add second flight, customize buffer)
- User taps "Upgrade" in settings
- Trial expiration (graceful, not aggressive)

**Never** show paywall:
- On first app launch
- On every app open
- As a modal without user action
- Blocking core functionality

### 2. Value-Focused Messaging

Paywall emphasizes what user **gains**, not what they're **missing**:

✅ Good: "Get unlimited flights and multiple transport options"
❌ Bad: "You can't add more flights without upgrading"

✅ Good: "Customize your buffer time for peace of mind"
❌ Bad: "Free users can't change buffer settings"

### 3. Clear Comparison

Paywall shows side-by-side Free vs Pro:

```
┌─────────────────────────────────────────┐
│                                         │
│  GoFast Pro                             │
│  More control, less stress              │
│                                         │
│  Free              Pro                  │
│  ─────────────────────────              │
│  1 flight          Unlimited            │
│  Auto timing       Custom buffers       │
│  1 transport       All options          │
│  1 location        Multiple             │
│                                         │
│  [Start Free Trial]                     │
│  $19.99/year • Cancel anytime           │
│                                         │
│  [Continue with Free]                   │
│                                         │
└─────────────────────────────────────────┘
```

### 4. Easy Dismissal

- Always show "Continue with Free" or "Not Now" button
- No forced watch-throughs or delays
- Respect user's choice to stay free

### 5. No Dark Patterns

- No fake urgency ("Only 2 spots left!")
- No hidden subscriptions (clear pricing)
- No surprise charges (confirm before purchase)
- No difficult cancellation (follow App Store guidelines)

## Paywall Trigger Points

### Soft Prompts (Contextual)

When user encounters a Pro feature:

**Adding second flight**:
```
"Pro users can track unlimited flights. 
Upgrade to add more destinations."
[Upgrade] [Maybe Later]
```

**Attempting to customize buffer**:
```
"Pro lets you set custom buffer times 
for each trip type."
[Learn More] [Keep Auto]
```

### Hard Paywall (Feature Gate)

When user confirms they want to use a Pro feature:

Show full paywall with:
- Feature list
- Pricing options (monthly/annual toggle)
- Trial information
- Restore purchases button
- Terms & Privacy links

## Subscription Management

### In-App Subscription UI

Settings screen includes:
- Current plan (Free / Pro Monthly / Pro Annual)
- Expiration/renewal date
- Upgrade/Downgrade options
- Restore Purchases button
- Cancel subscription link (opens App Store)

### Lifecycle Management

**Trial Active**:
- Show "Pro Trial" badge in settings
- Countdown to expiration
- Easy upgrade CTA

**Trial Expiring (48 hours)**:
- Gentle notification (if permitted)
- In-app banner (non-blocking)
- Clear upgrade path

**Subscription Active**:
- Thank you message in settings
- Feature usage stats (flights tracked, etc.)
- Referral option (post-MVP)

**Subscription Expired / Cancelled**:
- Graceful downgrade to Free
- Retain Pro data but limit functionality
- Easy resubscribe option
- No data loss (flights still visible, but editing limited)

## StoreKit Implementation

### Products

```swift
enum SubscriptionTier: String, CaseIterable {
    case monthly = "com.gofast.pro.monthly"
    case annual = "com.gofast.pro.annual"
    
    var displayName: String {
        switch self {
        case .monthly: return "Pro Monthly"
        case .annual: return "Pro Annual"
        }
    }
}
```

### Purchase Flow

```swift
class SubscriptionManager: ObservableObject {
    @Published var isPro: Bool = false
    @Published var expirationDate: Date?
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Handle successful purchase
            await updateSubscriptionStatus()
        case .userCancelled:
            // User cancelled, no action needed
            break
        case .pending:
            // Waiting for approval (family sharing, etc.)
            break
        @unknown default:
            break
        }
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
}
```

### Receipt Validation

- Use StoreKit 2 APIs (iOS 15+)
- Server-side validation for security (post-MVP)
- Local validation for offline use
- Grace period for renewal failures (billing retry)

## Analytics & Optimization

### Tracked Metrics

- Paywall impression rate (% of users who see paywall)
- Paywall conversion rate (% who purchase after seeing)
- Trial start rate (% who start trial)
- Trial conversion rate (% who convert after trial)
- Subscription retention (month-over-month)
- Revenue per user (ARPU)
- Feature usage correlation (which Pro features drive upgrades)

### A/B Testing (Post-MVP)

Test variations of:
- Paywall headline
- Feature list order
- Pricing presentation (monthly vs annual default)
- Trial length (7 vs 14 days)
- Button copy and colors

## Legal & Compliance

### Required Disclosures

- **Terms of Service**: Subscription terms, cancellation policy
- **Privacy Policy**: Data usage, no sale of personal data
- **EULA**: Standard Apple EULA or custom
- **Pricing**: Clear display of local currency

### App Store Compliance

- Follow App Store Review Guidelines for subscriptions
- No misleading claims about functionality
- Clear refund policy (follow Apple guidelines)
- Proper StoreKit implementation with receipt validation

## Post-MVP Monetization Ideas

### One-Time Purchases

- **Airport Database Pack**: Premium airport data with terminal maps
- **Lifetime Pro**: One-time purchase option
- **Gift Subscription**: Buy Pro for friends/family

### Partnerships

- **Affiliate Revenue**: Booking.com, Agoda for hotel suggestions
- **Transport Partnerships**: Revenue share with Uber/Grab for completed rides
- **Airport Lounge Access**: Priority Pass integration

### B2B Opportunities

- **Corporate Plans**: Bulk subscriptions for business travelers
- **Travel Agency Integration**: White-label version
- **Concierge Services**: Premium support tier

## Success Metrics

### Primary KPIs

- **Conversion Rate**: > 2% of active users upgrade to Pro
- **Trial Conversion**: > 25% of trial users convert to paid
- **Retention**: > 60% of subscribers retain after 6 months
- **ARPU**: $15+ annually per user (blend of free and paid)

### Secondary KPIs

- **Paywall CVR**: > 5% of paywall viewers purchase
- **Upgrade Reasons**: Which feature gates drive most upgrades
- **Downgrade Rate**: < 10% monthly churn
- **Support Tickets**: < 1% of subscribers have billing issues
