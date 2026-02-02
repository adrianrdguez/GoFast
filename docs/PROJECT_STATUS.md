# GoFast - Project Status

**Last Updated**: 2026-02-02  
**Current Status**: 🚧 Phase 2 - Google Calendar Integration (Primary Data Source)

---

## ✅ What's Working Now

### 1. Core Widget (MVP Complete)
- **Small Widget**: Shows flight number, "Leave by" time, countdown
- **Medium Widget**: Shows route, departure time, transport info, countdown
- **Adaptive Refresh**: 
  - > 90 min: Every 15 minutes
  - 30-90 min: Every 5 minutes  
  - < 30 min: Every 1-2 minutes
- **Urgency Indicators**: Green (relaxed) / Orange (soon) / Red (urgent)
- **Deep Links**: Tap widget opens app to flight detail
- **Empty State**: "No upcoming flights" with subtle subtitle
- **iOS 17+ Compatible**: Uses containerBackground API, theme adaptive

### 2. App Infrastructure
- **Flight Detection Service**: 3-tier priority scanning (structured → keywords → regex)
- **Google Calendar Integration**: Primary data source with OAuth2
  - Manual OAuth implementation (ASWebAuthenticationSession)
  - Secure token storage (Keychain)
  - Local flight filtering with confidence scoring
  - Actor-based token refresh (race condition protection)
- **Apple Calendar Fallback**: EventKit with iOS 17+ support
- **Leave Time Calculator**: Computes optimal departure with buffers
- **App Groups**: Shared data between app and widget (`group.com.gofast.shared`)
- **Mock Data Generator**: AA123/DMK test flight for development

### 3. Onboarding Flow (Phase 1 Complete)
- **3-Step Flow**: Welcome → Permissions → First Flight → Main App
- **Progress Bar**: Visual progress tracking
- **Slide Transitions**: Smooth animations between steps
- **Permission Pre-prompt**: Contextual explanation before system dialog (40-60% better acceptance)
- **Permission Status Handling**: Checks auth state first, auto-redirects to Settings if denied
- **Mock Flight Option**: Zero-friction testing available
- **Debug Access**: Hidden 5-tap gesture or #if DEBUG builds

### 4. UI Components
- **Custom Illustrations**: 4 animated vector scenes (plane, calendar, success, empty)
- **Animation System**: Button presses (0.1s), transitions (0.3s), shimmer effects
- **Design Quality**: Uber/Airbnb-level polish with haptic feedback

### 5. Debug Screen (Internal Testing)
- Calendar permission handling
- "Scan Calendar" button
- "Add Mock Flight" button  
- Widget controls: Save to Widget / Clear Widget / Refresh
- Flight list with debug details toggle
- **Hidden Access**: 5 taps on version number in main app

---

## 📁 Current File Structure

```
GoFast/
├── GoFast/                          # Main App Target
│   ├── GoFastApp.swift              # App entry point (routes to onboarding)
│   ├── GoFast.entitlements          # App Groups config
│   ├── Models/
│   │   ├── Airport.swift            # Airport data (15 major airports)
│   │   ├── Flight.swift             # Flight model with detection source
│   │   └── TransportOption.swift    # Transport modes & deep-links
│   ├── Views/
│   │   ├── ContentView.swift        # Debug screen UI
│   │   ├── Components/
│   │   │   ├── IllustrationViews.swift       # Custom vector illustrations
│   │   │   ├── AnimationExtensions.swift     # Animation utilities
│   │   │   └── HiddenDebugGesture.swift      # Debug access handler
│   │   └── Onboarding/
│   │       ├── OnboardingView.swift          # Main container
│   │       ├── OnboardingStep1Welcome.swift  # Welcome screen
│   │       ├── OnboardingStep2Permissions.swift # Calendar permission
│   │       └── OnboardingStep3FirstFlight.swift # Real vs mock selection
│   ├── ViewModels/
│   │   ├── FlightDebugViewModel.swift        # Debug screen logic
│   │   └── OnboardingViewModel.swift         # Onboarding state
│   ├── Resources/
│   │   └── GoogleOAuthConfig.plist           # Google OAuth configuration
│   └── Services/
│       ├── FlightDetectionService.swift      # Calendar scanning (Apple)
│       ├── FlightDetectionCoordinator.swift  # Unified data source coordinator
│       ├── FlightDataSource.swift            # Protocol + Google/Apple implementations
│       ├── GoogleCalendarAuthService.swift   # OAuth2 flow
│       ├── GoogleCalendarAPIService.swift    # Google Calendar API client
│       ├── KeychainService.swift             # Secure token storage
│       ├── LeaveTimeCalculator.swift         # Departure time calc
│       ├── SharedDataService.swift           # App Groups read/write
│       ├── MockFlightData.swift              # Test data generator
│       ├── PermissionsManager.swift          # Permission handling
│       └── SettingsView.swift                # Settings screen
├── GoFastWidget/                    # Widget Extension Target
│   ├── GoFastWidget.swift           # Widget configuration (@main)
│   ├── FlightTimelineEntry.swift    # Timeline entry + UrgencyLevel
│   ├── FlightTimelineProvider.swift # Adaptive refresh provider
│   ├── Airport.swift                # Shared model (copy)
│   ├── Flight.swift                 # Shared model (copy)
│   ├── SharedDataService.swift      # Shared service (copy)
│   ├── MockFlightData.swift         # Shared mock data (copy)
│   ├── Views/
│   │   ├── WidgetContainer.swift    # iOS 17+ containerBackground wrapper
│   │   ├── SmallFlightWidget.swift  # Compact layout
│   │   └── MediumFlightWidget.swift # Expanded layout
│   └── Info.plist
├── GoFastTests/                     # Unit tests (template)
├── GoFastUITests/                   # UI tests (template)
└── docs/                            # Documentation
    ├── README.md                    # Product vision & goals
    ├── PROJECT_STATUS.md            # This file
    ├── ROADMAP.md                   # Development phases
    ├── ARCHITECTURE.md              # MVVM structure
    ├── DATA_MODEL.md                # Models specification
    ├── WIDGETS.md                   # Widget specs
    ├── WIDGET_ARCHITECTURE.md       # Widget implementation
    ├── INTEGRATIONS.md              # External services
    └── MONETIZATION.md              # Business model
```

---

## 🚧 What's Next

### Phase 2: Transport Deep-links (In Progress)
- [ ] TransportDeepLinkService.swift - URL generation
- [ ] TransportAppChecker.swift - App installation check
- [ ] Make widget transport row tappable
- [ ] Uber/Grab/Maps integration

### Phase 3: Settings & Pro Foundation
- [ ] SettingsView.swift - Main settings screen
- [ ] Buffer customization (Pro feature)
- [ ] Paywall UI
- [ ] StoreKit integration

### Phase 4: Multiple Flights
- [ ] FlightListView.swift
- [ ] Smart notifications
- [ ] Pro: Unlimited flights

---

## 📊 Current Stats

- **Total Swift Files**: 35
- **New Files in Phase 2**: 7 (Google Calendar integration)
- **Lines of Code**: ~7,200 (estimated)
- **Documentation**: 9 markdown files
- **Build Status**: ✅ Both targets compile
- **Test Coverage**: Minimal (template only)

---

## 🎯 Phase 1 Success Criteria ✅

- [x] Onboarding completes without crashes
- [x] Calendar permission flow works
- [x] Mock flight option available
- [x] Real calendar detection integrated
- [x] Debug screen hidden but accessible
- [x] All animations run at 60fps
- [x] Slide transitions work correctly
- [x] Progress bar updates

---

## 📝 Notes

- **Widget Target**: Run separately in Xcode (`GoFastWidgetExtension` scheme)
- **App Groups**: `group.com.gofast.shared` - verified in both targets
- **Debug Access**: 5-tap on version number OR `#if DEBUG` builds
- **Mock Data**: AA123/DMK flight for development testing
- **Design**: Uber/Airbnb quality with custom illustrations

### Recent Fixes (2026-02-02)
- **Widget iOS 17+**: Fixed containerBackground API warning, now uses proper `.containerBackground(for: .widget)` with theme adaptation
- **Calendar Permission**: Fixed flow to check authorization status first, properly handles denied/restricted states with Settings redirect
- **Calendar Capability**: Requires Calendar capability enabled in Xcode (Signing & Capabilities)

### New: Google Calendar Integration (2026-02-02)
- **Primary Data Source**: Google Calendar API replaces Apple Calendar as main flight source
- **OAuth2 Implementation**: Manual implementation using ASWebAuthenticationSession (no external dependencies)
- **Secure Storage**: OAuth tokens stored in iOS Keychain
- **Local Flight Filtering**: Regex-based detection with confidence scoring (flight numbers, IATA codes, keywords)
- **Race Condition Protection**: Actor-based token refresh prevents concurrent refresh issues
- **Settings Screen**: Minimal UI to connect/disconnect Google account with last sync timestamp
- **Apple Calendar Fallback**: Gracefully falls back to Apple Calendar when Google not connected
- **Data Source Architecture**: Protocol-based abstraction enabling multiple source support

---

**Status**: Phase 2 IN PROGRESS 🚧 | Google Calendar Integration Complete  
**Next Action**: Testing on real device with Google Cloud credentials
