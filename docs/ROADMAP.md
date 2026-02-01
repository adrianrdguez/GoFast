# Roadmap

## 30-Day Development Timeline

### Week 1: Foundation & Core Detection
**Goal**: Basic flight detection and data model

**Tasks**:
- [ ] Finalize data models (Flight, Airport, TransportOption)
- [ ] Implement EventKit integration with structured event detection
- [ ] Build flight detection service with 3-tier priority (airport codes + keywords > keywords only > regex fallback)
- [ ] Basic widget scaffolding (no UI yet)
- [ ] App Groups setup for data sharing

**MVP Cut Line**: 
- Skip email parsing entirely
- Skip manual flight entry (auto-detection only for MVP)
- Skip flight status APIs

### Week 2: Transport & Calculation
**Goal**: Departure time calculation with real transport options

**Tasks**:
- [ ] Implement LeaveTimeCalculator with buffer logic
- [ ] Apple Maps integration for ETA calculation
- [ ] Deep-link support for Uber and Grab (MVP transport providers)
- [ ] Transport fallback logic (always fallback to Apple Maps)
- [ ] Domestic vs international airport procedure detection

**MVP Cut Line**:
- Skip Google Maps (Apple Maps only for MVP)
- Skip Bolt and other regional services
- Skip real-time traffic for ETA (use standard estimates)

### Week 3: Widget Implementation
**Goal**: Functional widgets in all three sizes

**Tasks**:
- [ ] Small widget: Essential info only (departure time, countdown)
- [ ] Medium widget: Add flight details and transport option
- [ ] Large widget: Full transport comparison + deep-links
- [ ] Widget refresh strategy and timeline updates
- [ ] Deep-link handling from widget to app

**MVP Cut Line**:
- Skip interactive widgets (iOS 17+) for broader compatibility
- Skip Live Activities (post-MVP feature)
- Skip widget customization beyond size

### Week 4: Polish & Monetization Foundation
**Goal**: App UI, paywall setup, and testing

**Tasks**:
- [ ] Onboarding flow and permissions handling
- [ ] Settings screen for buffer customization (Pro only)
- [ ] Free/Pro feature gating implementation
- [ ] Paywall UI (non-intrusive, value-focused)
- [ ] StoreKit integration for subscriptions
- [ ] Comprehensive testing and edge case handling

**MVP Cut Line**:
- Skip advanced analytics
- Skip referral or promotional features
- Skip family sharing setup (individual subscriptions only)

---

## MVP Scope vs Post-MVP

### MVP (Month 1)

**Free Tier**:
- 1 active flight (next upcoming only)
- Widget with single transport recommendation
- Automatic buffer calculation (90 min domestic, 180 min international)
- Apple Maps, Uber, Grab deep-links
- Calendar-based flight detection

**Pro Tier** (implemented but with basic paywall):
- Unlimited flight detection
- Multiple transport options in widget
- Customizable buffer times
- Multiple saved locations (home, hotel, etc.)

### Post-MVP (Months 2-3)

**Features**:
- [ ] Live Activities for lock screen
- [ ] Interactive widgets (iOS 17+)
- [ ] Google Maps and Bolt transport options
- [ ] Manual flight entry (for non-calendar users)
- [ ] Flight status integration (delays, gate changes)
- [ ] Smart notifications ("Leave in 15 minutes")
- [ ] Travel history and basic analytics
- [ ] Family sharing support
- [ ] Siri Shortcuts integration

**Platform Expansion**:
- [ ] watchOS complication
- [ ] iPad-optimized interface

---

## Scope Creep Prevention Rules

1. **The "When to Leave" Test**: Every feature must directly answer "when should I leave?" If it doesn't, it's post-MVP.

2. **No Feature Without User Pain**: Don't add features preemptively. Wait for user requests.

3. **Widget-First Constraint**: If a feature can't be expressed in a widget, reconsider its necessity.

4. **Calendar-Only MVP**: No email parsing, no manual entry, no flight search until MVP is solid.

5. **Three Transport Max**: Uber, Grab, Apple Maps only for MVP. Regional services come later.

6. **Single Flight Focus**: Free tier gets one flight. Don't overcomplicate multi-flight scenarios.

---

## Success Metrics for MVP

- [ ] Widget displays correct departure time in 95% of test cases
- [ ] Flight detection works with 80% of calendar events containing flights
- [ ] App launch to widget displaying data < 5 seconds
- [ ] Zero crashes in core user flows
- [ ] Subscription conversion rate > 2% (baseline for optimization)
