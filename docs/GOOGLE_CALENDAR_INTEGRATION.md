# Google Calendar Integration - Implementation Guide

**Last Updated:** 2026-02-02  
**Branch:** `feature/google-calendar-integration`  
**Status:** OAuth Flow Working, Google Cloud Console Configuration Required

---

## Overview

This document describes the complete Google Calendar integration implementation for GoFast, including OAuth2 authentication, flight data fetching, and UI components.

---

## Architecture

### Data Flow

```
User taps "Connect Google Calendar"
    ↓
SettingsView calls GoogleCalendarAuthService.signIn()
    ↓
ASWebAuthenticationSession opens browser
    ↓
User authenticates with Google
    ↓
Redirect to com.gofast://oauth2redirect
    ↓
App receives callback via .onOpenURL
    ↓
Tokens stored in Keychain
    ↓
FlightDetectionCoordinator uses GoogleCalendarDataSource
    ↓
Flights fetched from Google Calendar API
```

### Components

1. **GoogleCalendarAuthService** - OAuth2 flow management
2. **GoogleCalendarAPIService** - HTTP client for Calendar API
3. **FlightDetectionCoordinator** - Routes between Google/Apple Calendar
4. **SettingsView** - UI for connection management
5. **FlightDataSource Protocol** - Abstraction for multiple sources

---

## Configuration

### 1. Google Cloud Console Setup

#### Required Steps:

1. **Create OAuth 2.0 Credentials**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - APIs & Services → Credentials
   - Create OAuth 2.0 Client ID (iOS application type)
   - Bundle ID: `com.adrianrdguez.GoFast`

2. **Configure OAuth Consent Screen**
   - APIs & Services → OAuth consent screen
   - User Type: External (for testing)
   - App Name: "GoFast"
   - User support email: [your email]
   - Developer contact: [your email]
   - Authorized domains: (leave empty for now)

3. **Add Authorized Redirect URI**
   ```
   com.gofast://oauth2redirect
   ```

4. **Enable Google Calendar API**
   - APIs & Services → Library
   - Search "Google Calendar API"
   - Click Enable

5. **Add Test Users** (for testing mode)
   - OAuth consent screen → Test users
   - Add your Google email address

### 2. Local Configuration

#### GoogleOAuthConfig.plist

Located at: `GoFast/Resources/GoogleOAuthConfig.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CLIENT_ID</key>
    <string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
    <key>REDIRECT_URI</key>
    <string>com.gofast://oauth2redirect</string>
    <key>AUTH_ENDPOINT</key>
    <string>https://accounts.google.com/o/oauth2/v2/auth</string>
    <key>TOKEN_ENDPOINT</key>
    <string>https://oauth2.googleapis.com/token</string>
    <key>SCOPES</key>
    <array>
        <string>https://www.googleapis.com/auth/calendar.readonly</string>
    </array>
</dict>
</plist>
```

#### Info.plist

Ensure URL scheme is registered:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.gofast.googleoauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.gofast</string>
        </array>
    </dict>
</array>
```

---

## Implementation Details

### OAuth2 Flow

#### 1. Sign In Process

```swift
// In SettingsView
Button("Connect Google Calendar") {
    Task {
        do {
            let tokens = try await authService.signIn()
            // Handle success
        } catch {
            // Handle error
        }
    }
}
```

#### 2. Window Detection

The OAuth session requires a valid window for presentation. We use 4 fallback methods:

1. `UIApplication.shared.keyWindow`
2. Active window scenes
3. Any window scene
4. Any visible window

#### 3. Token Storage

Tokens are securely stored in iOS Keychain:
- Access token (with expiry)
- Refresh token
- Token expiry date

#### 4. Token Refresh

Automatic token refresh using Swift Actor to prevent race conditions:

```swift
private actor TokenRefreshActor {
    func performRefresh(...) async throws -> String
}
```

### Error Handling

#### Configuration Errors

```swift
@Published var isConfigValid: Bool = false
@Published var configError: String?
```

When config is invalid:
- "Connect" button is disabled
- Error message displayed in Debug Info section
- Detailed logs in console

#### OAuth Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `configNotFound` | Missing/invalid plist | Check GoogleOAuthConfig.plist |
| `noPresentationContext` | No window available | Check app is foreground |
| `sessionStartFailed` | ASWebAuthenticationSession failed | Check URL scheme registered |
| `invalidState` | CSRF protection failed | Retry authentication |
| `tokenExchangeFailed` | Code exchange failed | Check client ID/secret |

---

## UI Components

### SettingsView

Located at: `GoFast/Views/SettingsView.swift`

**Features:**
- Connection status indicator
- Connect/Disconnect buttons
- Last sync time display
- Debug Info section with:
  - Config validity status
  - Error messages
  - Signed in status

**States:**
1. **Not Connected** - Shows orange warning icon, "Connect" button
2. **Connected** - Shows green checkmark, last sync time, "Disconnect" button
3. **Config Error** - Shows red error icon, detailed error message

### Debug Screen

Located at: `GoFast/Views/ContentView.swift`

**New Features:**
- Data source indicator (Google = purple, Apple = cyan)
- Last sync timestamp (relative time)
- Connection status

---

## Testing

### Test Scenarios

#### 1. Fresh Install - No Calendar Permission

**Steps:**
1. Install app
2. Complete onboarding
3. Tap Settings (gear icon)
4. Check Debug Info shows "Config Valid: Yes"
5. Tap "Connect Google Calendar"

**Expected:**
- Browser opens to Google OAuth page
- After auth, returns to app
- Shows "Connected to Google Calendar"

#### 2. Apple Calendar Fallback

**Steps:**
1. Deny Google Calendar connection
2. Grant Apple Calendar permission
3. Go to Debug screen
4. Tap "Scan Calendar"

**Expected:**
- Data source shows "Apple Calendar" (cyan)
- Flights detected from Apple Calendar

#### 3. Config Error Handling

**Steps:**
1. Delete or corrupt GoogleOAuthConfig.plist
2. Open Settings

**Expected:**
- "Config Valid: No" shown
- Error message displayed
- Connect button disabled

### Debug Logging

Enable console logging to troubleshoot:

```
[GoogleAuth] Initializing auth service...
[GoogleAuth] ✅ Configuration loaded successfully
[GoogleAuth] 📍 Redirect URI: com.gofast://oauth2redirect
[SettingsView] onAppear - Config valid: true, Error: none
[GoogleAuth] Searching for presentation window...
[GoogleAuth] ✅ OAuth session started successfully
```

---

## Troubleshooting

### Common Issues

#### "Failed to start OAuth session"

**Causes:**
1. No valid window found
2. URL scheme not registered
3. App not in foreground

**Solutions:**
1. Check window detection logs
2. Verify Info.plist has CFBundleURLTypes
3. Ensure app is active when tapping button

#### "Authorization Error 400: invalid_request"

**Causes:**
1. OAuth consent screen not configured
2. Redirect URI mismatch
3. App in testing mode without test users

**Solutions:**
1. Complete OAuth consent screen in Google Cloud Console
2. Verify redirect URI matches exactly
3. Add your email as test user

#### "Config Valid: No"

**Causes:**
1. GoogleOAuthConfig.plist missing
2. Invalid XML format
3. Missing required fields

**Solutions:**
1. Check file exists in bundle
2. Validate XML syntax
3. Ensure all keys present (CLIENT_ID, REDIRECT_URI, etc.)

### Debug Checklist

- [ ] GoogleOAuthConfig.plist in bundle
- [ ] CLIENT_ID is valid (ends with .apps.googleusercontent.com)
- [ ] REDIRECT_URI uses :// not :/
- [ ] Info.plist has CFBundleURLTypes with com.gofast scheme
- [ ] Google Calendar API enabled in Cloud Console
- [ ] OAuth consent screen configured
- [ ] Test user added (if in testing mode)
- [ ] App built with latest changes

---

## Security Considerations

### Token Storage

- Access tokens stored in Keychain with accessibility level
- Refresh tokens never exposed to UI
- Automatic token expiry handling
- Secure deletion on sign out

### OAuth Security

- PKCE not implemented (not required for iOS native apps)
- State parameter validation prevents CSRF
- Authorization code exchanged server-side (via Google's servers)

### Best Practices

1. Never commit CLIENT_ID to public repos
2. Use different OAuth credentials for dev/prod
3. Implement certificate pinning for API calls
4. Clear Keychain on app uninstall (handled by iOS)

---

## Next Steps

### Immediate

1. Configure Google Cloud Console (see Configuration section)
2. Test on real device (simulator has OAuth limitations)
3. Add your email as test user

### Future Enhancements

1. **Token Expiry Notifications** - Warn user before token expires
2. **Background Sync** - Refresh flights periodically
3. **Multiple Accounts** - Support multiple Google accounts
4. **Offline Mode** - Cache flights when offline
5. **Biometric Auth** - Protect sensitive flight data

---

## References

- [Google OAuth 2.0 for iOS](https://developers.google.com/identity/protocols/oauth2/native-app)
- [ASWebAuthenticationSession Documentation](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [Google Calendar API Reference](https://developers.google.com/calendar/api/v3/reference)

---

## Support

For issues with:
- **Code/Build**: Check console logs and debug info
- **OAuth Flow**: Verify Google Cloud Console configuration
- **API Errors**: Check Google Calendar API quotas and permissions

---

**Last Commit:** 9eac913 - Implement OAuth flow fixes and UI enhancements for Google Calendar integration
