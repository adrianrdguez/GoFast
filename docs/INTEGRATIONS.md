# Integrations

## Overview

GoFast integrates with iOS system services and third-party apps to provide accurate departure times and seamless transport booking. This document outlines the integration strategy, permissions model, and fallback behaviors.

## Calendar Access (EventKit)

### Purpose
Scan user's calendar for flight events using 3-tier detection priority.

### Implementation

```swift
import EventKit

class CalendarService {
    private let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        // iOS 17+ uses new API, iOS 16 uses requestAccess(to:)
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }
    
    func fetchFlightEvents() async -> [EKEvent] {
        // Scan next 60 days for potential flight events
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 60, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
    }
}
```

### Privacy Requirements

- **NSCalendarsFullAccessUsageDescription** (iOS 17+) or **NSCalendarsUsageDescription**
- Clear explanation: "GoFast scans your calendar to automatically detect upcoming flights and calculate when you should leave."
- **Required Permission**: App cannot function without calendar access (core feature)

### Detection Strategy

See [DATA_MODEL.md](./DATA_MODEL.md) for detailed detection logic. Summary:

1. **Tier 1**: IATA airport codes + flight keywords (highest confidence)
2. **Tier 2**: Flight keywords only (medium confidence)
3. **Tier 3**: Flight number regex (lowest confidence, fallback)

### Caching Strategy

- Cache detected flights in App Groups
- Refresh every 15 minutes via background fetch
- Manual refresh available in app

## Maps & ETA Calculation (MapKit)

### Purpose
Calculate travel time from user's current location to airport.

### Implementation

```swift
import MapKit
import CoreLocation

class TransportService {
    func calculateETA(from origin: CLLocation, to airport: Airport) async throws -> TimeInterval {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: airport.latitude, longitude: airport.longitude)
        ))
        request.transportType = .automobile
        request.departureDate = Date()
        
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        // Get fastest route
        guard let route = response.routes.first else {
            throw TransportError.noRouteFound
        }
        
        return route.expectedTravelTime
    }
}
```

### Transport Modes

**Automobile** (Primary):
- Personal car
- Taxi / ride-hail
- Maps provides traffic-aware ETAs

**Transit** (Secondary):
- Available in supported cities
- Less reliable for airport trips (variable schedules)

**Walking** (Not Used):
- Airports are never walking distance

### Location Permissions

- **When In Use**: Required for current location to calculate ETA
- **NSLocationWhenInUseUsageDescription**: "GoFast uses your location to calculate travel time to the airport."
- **Optional**: App can work with manually entered addresses (Pro feature, post-MVP)

### Fallback Strategy

If MapKit fails:
1. Use historical average time for route
2. Apply conservative buffer (add 20% to estimated time)
3. Display warning in widget: "ETA estimated"

## External App Deep Links

### Strategy: Best-Effort with Universal Fallback

All transport deep-links attempt to open specific apps, but always fall back to Apple Maps if the app isn't installed.

### Apple Maps (Universal Fallback)

Always available on iOS. Zero friction.

```swift
func openAppleMaps(to airport: Airport) {
    let coordinates = "\(airport.latitude),\(airport.longitude)"
    let urlString = "http://maps.apple.com/?daddr=\(coordinates)&dirflg=d"
    
    if let url = URL(string: urlString) {
        UIApplication.shared.open(url)
    }
}
```

**Directions URL Parameters**:
- `daddr`: Destination address or coordinates
- `saddr`: Source address (omit for "Current Location")
- `dirflg=d`: Driving directions
- `dirflg=r`: Public transit (if available)

### Uber (Europe / US)

**Requirements**: Uber app must be installed

```swift
func openUber(to airport: Airport) {
    // Try Uber app first
    let uberUrl = URL(string: """
        uber://?action=setPickup\
        &pickup[latitude]=CURRENT_LAT\
        &pickup[longitude]=CURRENT_LON\
        &dropoff[latitude]=\(airport.latitude)\
        &dropoff[longitude]=\(airport.longitude)\
        &dropoff[nickname]=\(airport.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        """)!
    
    if UIApplication.shared.canOpenURL(uberUrl) {
        UIApplication.shared.open(uberUrl)
    } else {
        // Fallback to App Store or Apple Maps
        openAppleMaps(to: airport)
    }
}
```

**Note**: Uber deep-linking API requires pickup coordinates. In practice, use current location or omit for "my location".

### Grab (Southeast Asia)

**Requirements**: Grab app must be installed

```swift
func openGrab(to airport: Airport) {
    // Grab URL scheme (simplified - actual implementation may vary)
    let grabUrl = URL(string: "grab://")!
    
    if UIApplication.shared.canOpenURL(grabUrl) {
        // Open Grab, user manually enters destination
        // Grab doesn't support pre-filled destination in URL scheme
        UIApplication.shared.open(grabUrl)
    } else {
        openAppleMaps(to: airport)
    }
}
```

**Limitation**: Grab's URL scheme is limited. May need to open app and let user complete booking manually.

### Deep Link Manager

```swift
class DeepLinkManager {
    enum TransportApp {
        case appleMaps
        case uber
        case grab
        
        var urlScheme: String {
            switch self {
            case .appleMaps: return "http://maps.apple.com"
            case .uber: return "uber://"
            case .grab: return "grab://"
            }
        }
    }
    
    func openTransport(_ app: TransportApp, to airport: Airport) {
        switch app {
        case .appleMaps:
            openAppleMaps(to: airport)
        case .uber:
            openUber(to: airport)
        case .grab:
            openGrab(to: airport)
        }
    }
    
    func isAppInstalled(_ app: TransportApp) -> Bool {
        guard let url = URL(string: app.urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
```

## Permissions Strategy

### Required Permissions

These permissions are essential for core functionality:

1. **Calendar Access** (EventKit)
   - **Purpose**: Detect upcoming flights
   - **When Requested**: On first app launch, before onboarding completes
   - **If Denied**: Show settings prompt with explanation
   - **User Impact**: App cannot function without this

2. **Location When In Use** (CoreLocation)
   - **Purpose**: Calculate ETA from current location to airport
   - **When Requested**: When user first views transport options
   - **If Denied**: Allow manual address entry (Pro feature) or show generic ETAs
   - **User Impact**: Degraded experience but app still works

### Optional Permissions

These enhance experience but aren't required:

1. **Notifications** (UserNotifications)
   - **Purpose**: "Leave in 15 minutes" alerts (post-MVP)
   - **When Requested**: After user has used app for 3+ days
   - **If Denied**: No impact on core functionality
   - **User Impact**: Missing proactive reminders only

2. **Background Location** (CoreLocation)
   - **Purpose**: Automatic ETA updates as user moves
   - **When Requested**: Post-MVP feature
   - **If Denied**: Manual refresh only
   - **User Impact**: Less real-time accuracy

### Permission UI Guidelines

- **Pre-prompt**: Explain why permission is needed before system dialog
- **Education screen**: Show benefits with illustration
- **Graceful degradation**: App works with limited permissions
- **Settings deep-link**: Easy access to re-enable permissions
- **No nagging**: Ask once, then only on user action (tap "enable notifications")

### Permission Request Flow

```
App Launch
    ↓
Onboarding Screen 1: Welcome
    ↓
Onboarding Screen 2: Calendar Permission Request
    ↓
[System Calendar Dialog]
    ↓
If Granted: Continue to app
If Denied: Show education screen with "Open Settings" button
    ↓
Main App (location requested on first transport view)
```

## URL Scheme Configuration

### Custom URL Scheme

**Identifier**: `gofast`

**Info.plist Configuration**:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.gofast.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>gofast</string>
        </array>
    </dict>
</array>
```

### URL Routes

| Route | Action |
|-------|--------|
| `gofast://` | Open app to home |
| `gofast://flight/[id]` | Open specific flight details |
| `gofast://settings` | Open settings screen |
| `gofast://onboarding` | Open onboarding (for settings reset) |
| `gofast://transport/uber?airport=[code]` | Open Uber to specific airport |
| `gofast://transport/grab?airport=[code]` | Open Grab to specific airport |

## Integration Testing

### Automated Tests

- Mock EventKit with sample calendar events
- Test all 3 detection tiers
- Verify deep-link fallback chains
- Test permission denial scenarios

### Manual Testing

- Test with real calendar events (flight bookings)
- Verify Uber/Grab app detection
- Test Apple Maps fallback on device without ride apps
- Test in different regions (US, EU, SEA)

## Error Handling

### Calendar Errors
- **Access Denied**: Show settings prompt
- **No Events Found**: Show empty state with instructions
- **Malformed Data**: Skip event, log for debugging

### Maps Errors
- **No Route**: Use historical average + warning
- **Location Unavailable**: Prompt for manual entry
- **Network Error**: Use cached ETA if available

### Deep Link Errors
- **App Not Installed**: Automatic fallback to Apple Maps
- **Invalid URL**: Open app to relevant screen
- **App Opens but Errors**: Not our responsibility (user sees app error)

## Future Integrations (Post-MVP)

- **Google Maps**: Additional transport options
- **Bolt**: European ride-hailing
- **Flight Status APIs**: Real-time delay information
- **Siri Shortcuts**: "When should I leave for my flight?"
- **Apple Wallet**: Scan boarding passes for flight detection
