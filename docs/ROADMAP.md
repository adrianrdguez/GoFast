# GoFast Development Roadmap

**Last Updated**: 2026-02-02  
**Current Status**: ✅ Phase 1 Complete - Onboarding & Core Infrastructure

---

## ✅ COMPLETED - Foundation & Widget MVP (Pre-Phase 1)

### What We Built
- ✅ Data models (Flight, Airport, TransportOption)  
- ✅ EventKit integration with 3-tier detection
- ✅ FlightDetectionService (structured → keywords → regex)
- ✅ LeaveTimeCalculator with buffer logic
- ✅ Widget implementation (Small + Medium)
  - Adaptive refresh (15min/5min/1-2min)
  - Urgency levels (green/orange/red)
  - Deep-links to app
- ✅ App Groups configured (`group.com.gofast.shared`)
- ✅ Mock data generator (AA123/DMK)
- ✅ Debug screen for testing

**Result**: Working widget displaying flight data with countdown

---

## ✅ COMPLETED - Phase 1: Onboarding & Core UX

### Deliverables

#### New Files Created (13 files)
**UI Components:**
- ✅ `IllustrationViews.swift` - Custom SwiftUI vector illustrations (4 animated scenes)
- ✅ `AnimationExtensions.swift` - Button presses, transitions, shimmer effects
- ✅ `HiddenDebugGesture.swift` - 5-tap or #if DEBUG debug access

**Services:**
- ✅ `PermissionsManager.swift` - Calendar permission with pre-prompt (40-60% better acceptance)

**ViewModels:**
- ✅ `OnboardingViewModel.swift` - 3-step flow state management

**Onboarding Flow:**
- ✅ `OnboardingStep1Welcome.swift` - Welcome screen with plane animation
- ✅ `OnboardingStep2Permissions.swift` - Calendar permission with context
- ✅ `OnboardingStep3FirstFlight.swift` - Real vs mock flight selection
- ✅ `OnboardingView.swift` - Main container with progress bar and transitions

**Updated:**
- ✅ `GoFastApp.swift` - Entry point routes to onboarding

### Key Features
- **3-Step Flow**: Welcome → Permissions → First Flight → Main App
- **Progress Bar**: Visual progress (0% → 33% → 66% → 100%)
- **Slide Transitions**: Smooth 0.3s animations between steps
- **Permission Strategy**: Contextual explanation BEFORE system dialog
- **Mock Flight Option**: Zero-friction testing (no calendar needed)
- **Debug Access**: Hidden 5-tap gesture on version number

### Design Quality
- Uber/Airbnb-level animations (0.1-0.3s micro-interactions)
- Custom SwiftUI vector illustrations (no external assets)
- Haptic feedback on button presses
- System adaptive colors (light/dark mode)

---

## 🚧 Phase 2: Transport Deep-links (Next)

**Goal**: Open external apps for booking rides

### Deliverables

#### New Files to Create
- [ ] `TransportDeepLinkService.swift` - URL generation for Uber/Grab/Maps
- [ ] `TransportAppChecker.swift` - Check if apps installed
- [ ] `TransportActionSheet.swift` - Bottom sheet for transport selection

#### Updates Needed
- [ ] Update `MediumFlightWidget.swift` - Make transport row tappable
- [ ] Update `TransportOption.swift` - Add execute() method
- [ ] Update `ContentView.swift` - Add "Test Deep-links" debug section

### Key Features
- **Uber Deep-link**: iOS universal link with pickup/dropoff
- **Grab Deep-link**: SEA region support
- **Apple Maps**: Universal fallback (always works)
- **Best-effort Chain**: Try Uber → Grab → Maps

**Timeline**: 1 week  
**Dependencies**: Phase 1 complete ✅

---

## 📋 Phase 3: Settings & Pro Foundation

**Goal**: Paywall foundation with buffer customization

### Deliverables

#### New Files to Create
- [ ] `SettingsView.swift` - Main settings screen
- [ ] `SettingsViewModel.swift` - Settings state management
- [ ] `ProFeatureGate.swift` - Feature locking mechanism
- [ ] `BufferSettingsView.swift` - Custom buffer slider (Pro)
- [ ] `PaywallView.swift` - Non-intrusive upgrade screen
- [ ] `SubscriptionManager.swift` - StoreKit integration (ready)

### Key Features

**Free Tier:**
- View upcoming flight
- Automatic buffer (90min domestic / 180min international)
- Single transport option

**Pro Tier** ($2.99/month or $19.99/year):
- **Buffer Customization**: 0-60 minutes (slider with presets)
- Unlimited flights (Phase 4)
- Multiple transport options

**Paywall Strategy:**
- Soft paywall: Show Pro benefits when hitting limit
- Contextual: "Pro users can customize buffer time"
- Easy dismiss: "Not now" always available

**Timeline**: 1 week  
**Dependencies**: Phase 2 complete

---

## 📋 Phase 4: Multiple Flights & Polish

**Goal**: Pro users track unlimited flights

### Deliverables
- [ ] `FlightListView.swift` - Manage multiple flights
- [ ] `FlightDetailView.swift` - Individual flight details
- [ ] `SmartNotificationManager.swift` - "Leave in 15 minutes" alerts

### Key Features
- List view with upcoming flights
- Widget shows most urgent by default
- Smart notifications for departure time
- Pro: Unlimited, Free: 1 active

**Timeline**: 1-2 weeks  
**Dependencies**: Phase 3 complete

---

## 📋 Phase 5: Advanced Features (Month 2+)

**Goal**: Premium features for power users

- [ ] **Live Activities** - Lock screen countdown (iOS 16+)
- [ ] **Interactive Widgets** - Buttons on home screen (iOS 17+)
- [ ] **Manual Flight Entry** - For non-calendar users
- [ ] **Flight Status API** - Real-time delays and gate changes
- [ ] **Trip History** - Analytics and past trips
- [ ] **Apple Watch** - Complications and app

---

## 🎯 Current Priorities

### This Week (Phase 2)
1. Transport deep-link service
2. Make widget transport row tappable
3. Test Uber/Grab/Maps integration

### Next Week (Phase 3)
1. Settings screen
2. Buffer customization (Pro)
3. Paywall UI

---

## ✅ Success Criteria by Phase

### Phase 1 ✅ COMPLETE
- [x] Onboarding completes without crashes
- [x] Calendar permission > 70% acceptance
- [x] Mock flight flow works
- [x] Debug screen hidden but accessible

### Phase 2 (Next)
- [ ] Uber deep-link opens app
- [ ] Grab deep-link works (SEA)
- [ ] Apple Maps fallback always works
- [ ] Widget transport row is tappable

### Phase 3
- [ ] Settings screen accessible
- [ ] Buffer customization works (Pro)
- [ ] Paywall shows contextually
- [ ] StoreKit integrated

---

## 🎨 Design System (Established)

**Animations**:
- Micro: 0.1s (button presses)
- Quick: 0.2s (state changes)
- Standard: 0.3s (page transitions)
- Spring: Bouncy for success states

**Illustrations**:
- Custom SwiftUI vector shapes
- Animated with SwiftUI native (no Lottie yet)
- System adaptive colors

**Typography**:
- SF fonts throughout
- Clear hierarchy (title → body → caption)

---

## 📝 Notes

- **Widget Target**: Must be run separately in Xcode
- **App Groups**: Critical for data sharing
- **Debug Access**: 5-tap on version OR #if DEBUG builds
- **Mock Data**: AA123/DMK used for development

---

**Status**: Phase 1 COMPLETE ✅ | Ready for Phase 2  
**Last Commit**: f634183 - Widget MVP with onboarding
