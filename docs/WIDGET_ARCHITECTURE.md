# Widget Architecture Documentation

## Overview

GoFast uses WidgetKit to provide timeline-based widgets that display the optimal departure time for the user's next flight. The widget is the **core product** and updates automatically based on urgency.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        APP TARGET                           │
│  ┌─────────────────┐      ┌─────────────────────────────┐  │
│  │ FlightDetection │─────▶│    App Groups (Shared)      │  │
│  │     Service     │      │  • UserDefaults             │  │
│  └─────────────────┘      │  • Flight data (JSON)       │  │
│                           │  • Last update timestamp    │  │
│  ┌─────────────────┐      └─────────────────────────────┘  │
│  │  ContentView    │                   │                   │
│  │   (Debug UI)    │                   │                   │
│  └─────────────────┘                   │                   │
└────────────────────────────────────────┼────────────────────┘
                                         │
┌────────────────────────────────────────┼────────────────────┐
│                      WIDGET TARGET     │                    │
│                                        ▼                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              TimelineProvider                        │  │
│  │  • Reads from App Groups                             │  │
│  │  • Generates TimelineEntries (adaptive intervals)    │  │
│  │  • Requests reload based on urgency                  │  │
│  └──────────────────────┬───────────────────────────────┘  │
│                         │                                   │
│  ┌──────────────────────┴───────────────────────────────┐  │
│  │           FlightWidgetEntryView                      │  │
│  │  • SmallWidgetView (compact layout)                  │  │
│  │  • MediumWidgetView (expanded layout)                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. TimelineEntry

**File**: `Widgets/FlightTimelineEntry.swift`

```swift
struct FlightTimelineEntry: TimelineEntry {
    let date: Date                    // Required by TimelineEntry
    let flight: Flight?               // The flight to display
    let leaveTime: Date?              // Calculated leave time
    let timeUntilLeave: TimeInterval? // Countdown
    let urgencyLevel: UrgencyLevel    // Visual urgency indicator
    let isMockData: Bool              // Flag for mock data
}

enum UrgencyLevel {
    case relaxed   // > 90 min (green accent)
    case soon      // 30-90 min (orange accent)
    case urgent    // < 30 min (red accent)
}
```

### 2. TimelineProvider

**File**: `Widgets/FlightTimelineProvider.swift`

Implements adaptive refresh rates based on urgency:

- **Normal (> 90 min)**: Refresh every 15 minutes
- **Soon (30-90 min)**: Refresh every 5 minutes
- **Urgent (< 30 min)**: Refresh every 1 minute

Apple allows increased refresh frequency for time-sensitive content. The timeline generates multiple future entries with appropriate intervals.

### 3. Widget Configuration

**File**: `Widgets/GoFastWidget.swift`

```swift
@main
struct GoFastWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "FlightWidget",
            provider: FlightTimelineProvider()
        ) { entry in
            FlightWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "gofast://flight/\(entry.flight?.id ?? "")"))
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
```

**Features**:
- Static configuration (no user setup required for MVP)
- Deep link support (tap opens app to flight detail)
- Two sizes: Small and Medium

### 4. Data Sharing

**File**: `Services/SharedDataService.swift`

Uses App Groups (`group.com.gofast.shared`) for data sharing:

- Saves flight as JSON to UserDefaults
- Triggers widget reload via `WidgetCenter`
- Checks configuration status

**Workflow**:
1. App detects/saves flight
2. Flight encoded to JSON
3. Saved to shared UserDefaults
4. `WidgetCenter.shared.reloadTimelines()` called
5. Widget reads data on next refresh

### 5. Mock Data

**File**: `Services/MockFlightData.swift`

Generates test flight (AA123 from DMK) for development:

```swift
MockFlightData.generate()  // Returns Flight instance
```

Useful for testing widget UI without real calendar events.

## Widget Views

### Small Widget

**File**: `Widgets/Views/SmallFlightWidget.swift`

Layout:
```
┌─────────────────────┐
│ ✈️ AA123           │
│                     │
│ Leave by            │
│ 2:45 PM             │
│                     │
│ 🚗 45 min          │
└─────────────────────┘
```

Shows:
- Flight number with urgency icon
- Leave-by time (prominent)
- Countdown with transport icon

### Medium Widget

**File**: `Widgets/Views/MediumFlightWidget.swift`

Layout:
```
┌─────────────────────────────────┐
│ ✈️ AA123         │ Leave by   │
│ DMK → BKK        │ 2:45 PM    │
│ Depart: 5:30 PM  │ (45 min)   │
├─────────────────────────────────┤
│ 🚗 Car  │ ETA: 45 min │ [Open]│
└─────────────────────────────────┘
```

Shows:
- Flight number and route
- Departure and leave-by times
- Transport mode and ETA
- Open app button

### Empty State

When no flights available:
- Airplane icon
- "No upcoming flights"
- "Add a flight in GoFast" (subtle)

## Visual Design

### Background
- Uses `systemMaterial` for adaptive light/dark
- Respects system appearance automatically

### Urgency Colors
Used as accents (not full backgrounds):
- **Relaxed** (> 90 min): Green
- **Soon** (30-90 min): Orange
- **Urgent** (< 30 min): Red

Applied to:
- Status icons
- Countdown text
- Leave-by time (in medium widget)

## Deep Linking

Widget tap opens app directly to flight:

```swift
.widgetURL(URL(string: "gofast://flight/\(flight.id)"))
```

URL scheme handled in app via `onOpenURL`.

## Testing

### Debug Screen Integration

The debug screen (ContentView) provides buttons to:

1. **Save Flight to Widget**: Saves current flight to App Groups
2. **Clear Widget Data**: Removes flight and triggers empty state
3. **Refresh Widget**: Manually triggers timeline reload

### Testing Flow

1. Launch app
2. Tap "Add Mock Flight"
3. Tap "Save Flight to Widget"
4. Go to home screen
5. Long press → Edit Home Screen
6. Tap + button → Search "GoFast"
7. Add Small or Medium widget
8. Verify flight displays with countdown

## App Groups Configuration

**Required Setup**:
1. Enable "App Groups" capability in both targets
2. Use group ID: `group.com.gofast.shared`
3. Verify in Signing & Capabilities

**Troubleshooting**:
- If widget shows empty: Check App Groups is enabled for both targets
- If data doesn't update: Verify `WidgetCenter.reloadTimelines()` is called
- If build fails: Ensure both targets have matching group ID

## Performance Considerations

- Widget reads cached data only (no network calls)
- Complex calculations happen in app
- Timeline entries pre-computed
- Refresh rates adaptive to urgency
- Minimal view hierarchy for fast rendering

## Future Enhancements

- Large widget size (full transport comparison)
- Interactive widgets (iOS 17+)
- Live Activities for lock screen
- Intent-based configuration (user selects flight)
- Smart Stack relevance scores

## Implementation Files

| File | Purpose |
|------|---------|
| `Widgets/GoFastWidget.swift` | Widget entry point and configuration |
| `Widgets/FlightTimelineEntry.swift` | Timeline entry model with urgency |
| `Widgets/FlightTimelineProvider.swift` | Adaptive timeline generation |
| `Widgets/Views/SmallFlightWidget.swift` | Small size UI |
| `Widgets/Views/MediumFlightWidget.swift` | Medium size UI |
| `Services/SharedDataService.swift` | App Groups read/write |
| `Services/MockFlightData.swift` | Test data generator |

## References

- [Apple WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [Timeline Provider Guide](https://developer.apple.com/documentation/widgetkit/timelineprovider)
- [App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
