# GoFast

## Product Vision

GoFast is a widget-first iOS app that answers one critical question: **"When should I leave home to arrive perfectly on time for my flight?"** 

The app automatically detects upcoming flights from the user's calendar and calculates the ideal departure time based on real-time transport options from their current location. No manual entry, no complex interfaces—just glance at your home screen widget and know exactly when to head out. The core experience lives in the widget; the main app exists primarily for initial setup and configuration.

## Core Value Proposition

- **Zero-effort flight detection**: Automatically finds flights in your calendar using airport codes and event keywords
- **Smart departure calculation**: Factors in real-time traffic, transport mode, airport procedures, and personalized buffers
- **Always-visible widget**: Critical departure time information available at a glance, right on your home screen
- **Calm, reliable experience**: Fewer features, higher reliability—everything designed around the single question of when to leave

## Non-Goals (What We Don't Do)

GoFast intentionally avoids these features to maintain focus and reliability:

- **Flight booking or ticket purchasing**: We detect existing flights, don't help you buy new ones
- **Real-time flight status tracking**: Departure times change; we don't track delays or gate changes
- **Email parsing**: No inbox scanning in MVP—calendar events only
- **Social features**: No sharing departure times, no travel community
- **Multi-city trip planning**: Single flight focus—each trip treated independently
- **Historical travel data**: No "your travel stats" or retrospective analytics
- **Airport maps or terminal navigation**: Gate information only, not wayfinding

## Widget-First Philosophy

The widget is not an accessory—**it is the product**. Every design decision prioritizes the widget experience:

- Widget shows the single most important piece of information: "Leave by 2:45 PM"
- App screens exist only to configure widget behavior and manage settings
- Data architecture optimized for App Groups sharing between app and widget
- Update strategy designed around widget refresh constraints and battery efficiency
- Deep-links from widget back to app for configuration, not content browsing

This philosophy ensures we solve one problem exceptionally well rather than many problems poorly.
