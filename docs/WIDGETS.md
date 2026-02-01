# Widgets

## Overview

GoFast provides three widget sizes: small, medium, and large. Each serves different user needs while maintaining the core focus: **telling the user exactly when to leave**.

## Widget Types

### Small Widget (SystemSmall)

**Purpose**: Essential information at a glance

**Data Displayed**:
- Primary departure time: "Leave by 2:45 PM"
- Countdown timer: "45 min" or "In 2 hrs"
- Flight indicator: Airline icon or generic flight symbol
- Minimal transport info: Icon only (car, taxi, transit)

**Layout**:
```
┌─────────────────┐
│  ✈️  AA123     │
│                 │
│  Leave by      │
│   2:45 PM      │
│                 │
│    🚗 45 min   │
└─────────────────┘
```

**Use Case**: Primary home screen placement. Most important widget.

**Deep-link**: Tapping opens app to flight details

---

### Medium Widget (SystemMedium)

**Purpose**: More context without opening the app

**Data Displayed**:
- Flight number and departure airport
- Departure time and gate (if known)
- Leave-by time with countdown
- Primary transport recommendation with ETA
- Cost estimate (if available)

**Layout**:
```
┌─────────────────────────┐
│  ✈️ AA123  │  Leave by  │
│  DMK → BKK │   2:45 PM  │
│            │   (45 min) │
├─────────────────────────┤
│  🚗 Taxi   ETA 45 min   │
│  ฿350-450  [Open Uber]  │
└─────────────────────────┘
```

**Use Case**: Secondary home screen or widget stack

**Deep-link**: 
- Left side → Flight details
- Right side/transport → Opens transport app

---

### Large Widget (SystemLarge)

**Purpose**: Full transport comparison and detailed information

**Data Displayed**:
- Complete flight details (number, route, time, terminal, gate)
- Multiple transport options (up to 3)
- Leave-by time for each option
- Cost comparison
- Reliability indicators
- Direct action buttons

**Layout**:
```
┌──────────────────────────────┐
│  ✈️ AA123                    │
│  Don Mueang (DMK) Terminal 1 │
│  Gate A12  │  Depart 5:30 PM │
├──────────────────────────────┤
│  LEAVE BY: 2:45 PM (2h 45m)  │
├──────────────────────────────┤
│  🚗 Taxi         45 min  ฿400│
│     [Open Grab →]            │
│  🚊 Train        60 min  ฿50 │
│     [Open Maps →]            │
│  🚙 Car          50 min  Free│
│     [Open Maps →]            │
└──────────────────────────────┘
```

**Use Case**: iPad home screen, dedicated travel widget stack

**Deep-links**: Each transport row links to respective app

---

## Update Strategy

### Timeline-Based Updates

Widgets use WidgetKit's TimelineProvider for efficient refresh:

```swift
struct FlightProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let flights = loadFlightsFromAppGroups()
        
        // Create timeline entries every 15 minutes
        var entries: [FlightEntry] = []
        for minuteOffset in stride(from: 0, to: 60, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = FlightEntry(date: entryDate, flights: flights)
            entries.append(entry)
        }
        
        // Update timeline after 1 hour
        let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}
```

### Refresh Constraints

- **iOS Budget**: System limits widget refreshes to ~5-15 per day
- **Smart Updates**: App triggers widget reload only when data changes
- **Critical Moments**: 1 hour before leave time, widget updates every 5 minutes (if budget allows)
- **Background Sync**: App refreshes data every 15 minutes via background fetch

### Update Triggers

Widget reloads when:
1. User opens app and flight data changes
2. Background app refresh detects new flights
3. Departure time approaches (automatic system update)
4. User manually refreshes widget (iOS 17+ feature, post-MVP)

```swift
// In app, after data update:
WidgetCenter.shared.reloadTimelines(ofKind: "FlightWidget")
```

### Battery Efficiency

- Widgets read cached data from App Groups (no heavy calculations)
- No network requests from widget (all data pre-fetched by app)
- Timeline entries computed in advance, not on each refresh
- Minimal view hierarchy for fast rendering

## Interaction Limitations

### WidgetKit Constraints

- **No Buttons**: Widgets can't have interactive buttons (pre-iOS 17)
- **Tap Only**: Entire widget is one tappable area, or use Link views
- **No Text Input**: Can't enter data in widget
- **Limited Animations**: Static views only
- **Size Constraints**: Fixed aspect ratios per widget size

### Deep-Link Strategy

All widget interactions use deep-links:

**URL Scheme**: `gofast://`

**Routes**:
- `gofast://` → App home
- `gofast://flight/[id]` → Specific flight details
- `gofast://settings` → Settings screen
- `gofast://transport/[mode]` → Transport options view
- `gofast://open/[app]/[url]` → External app with fallback

**Implementation**:
```swift
// In widget view
Link(destination: URL(string: "gofast://flight/\(flight.id)")!) {
    FlightWidgetView(flight: flight)
}

// In app
.onOpenURL { url in
    handleDeepLink(url)
}
```

### External App Deep Links

Transport deep-links follow best-effort strategy:

**Apple Maps** (Universal):
```
http://maps.apple.com/?daddr=Airport+Name&dirflg=d
```

**Uber** (if installed, else fallback):
```
uber://?action=setPickup&pickup=my_location&dropoff[formatted_address]=Airport
```

**Grab** (SEA region):
```
grab://open?screen=booking&destination=Airport
```

**Fallback Chain**:
1. Try to open specific app (Uber/Grab)
2. If app not installed, try Apple Maps
3. If Maps fails, open app to transport selection screen

## Widget Configuration

### IntentConfiguration (iOS 17+)

Post-MVP: Allow users to configure widget from home screen:
- Select which flight to display (if multiple)
- Choose transport mode preference
- Set custom buffer time (Pro feature)

### StaticConfiguration (MVP)

MVP uses static configuration:
- Widget automatically displays most imminent flight
- No user configuration needed
- Zero-friction setup

## Empty States

### No Flights Detected

**Small**:
```
┌─────────────────┐
│    ✈️          │
│                 │
│  No upcoming   │
│    flights     │
│                 │
│  [Open App]    │
└─────────────────┘
```

**Medium/Large**: Show instructions for calendar integration

### No Calendar Access

Show permission request prompt in widget:
```
┌─────────────────┐
│    ⚠️          │
│                 │
│  Calendar      │
│  access needed │
│                 │
│  [Setup]       │
└─────────────────┘
```

### Flight Departed

Show next flight or "all caught up" message:
```
┌─────────────────┐
│    ✓           │
│                 │
│  Flight        │
│  departed      │
│                 │
│  Next: AA456   │
└─────────────────┘
```

## Implementation Guidelines

### Code Structure

```
Widgets/
├── FlightWidget.swift          # WidgetBundle entry point
├── FlightProvider.swift        # TimelineProvider implementation
├── FlightEntry.swift           # TimelineEntry model
├── Views/
│   ├── SmallFlightWidget.swift
│   ├── MediumFlightWidget.swift
│   └── LargeFlightWidget.swift
└── Components/
    ├── FlightInfoView.swift
    ├── TransportRowView.swift
    └── CountdownView.swift
```

### Best Practices

1. **Keep it simple**: One idea per widget size
2. **Optimize for glance**: User should understand in 2 seconds
3. **Consistent branding**: Use app colors, fonts, iconography
4. **Dark mode support**: Widgets must look good in both modes
5. **Accessibility**: Support Dynamic Type and VoiceOver
6. **Preview providers**: Include widget previews for all sizes

### Performance Targets

- Widget render time: < 100ms
- Memory footprint: < 5MB
- Timeline reload: < 1 second
- Data loading: Read from cache only (no network)
