//
//  GoogleCalendarAuthService.swift
//  GoFast
//
//  Manages Google OAuth2 authentication flow with automatic token refresh.
//  Uses ASWebAuthenticationSession for secure OAuth and Keychain for token storage.
//

import AuthenticationServices
import Combine
import Foundation
import SwiftUI

/// Actor to prevent concurrent token refresh race conditions
private actor TokenRefreshActor {
    private var isRefreshing = false
    private var refreshTask: Task<String, Error>?
    
    /// Ensures only one token refresh happens at a time
    func performRefresh(refreshOperation: @escaping () async throws -> String) async throws -> String {
        // If already refreshing, wait for that task
        if isRefreshing, let existingTask = refreshTask {
            return try await existingTask.value
        }
        
        // Start new refresh
        isRefreshing = true
        let task = Task {
            defer { 
                isRefreshing = false
                refreshTask = nil
            }
            return try await refreshOperation()
        }
        
        refreshTask = task
        return try await task.value
    }
}

    /// Manages Google OAuth2 authentication flow
@MainActor
class GoogleCalendarAuthService: NSObject, ObservableObject {
    static let shared = GoogleCalendarAuthService()
    
    @Published var isSignedIn: Bool = false
    @Published var configError: String?
    @Published var isConfigValid: Bool = false
    
    private var webAuthSession: ASWebAuthenticationSession?
    private var completionHandler: ((Result<GoogleAuthTokens, Error>) -> Void)?
    private var pendingAuthCode: String?
    private var pendingExpectedState: String?
    private let tokenRefreshActor = TokenRefreshActor()
    private var oauthConfig: GoogleOAuthConfig?
    
    // MARK: - Configuration
    
    /// Loads OAuth configuration safely without crashing
    private func loadConfig() -> GoogleOAuthConfig? {
        // Return cached config if available
        if let config = oauthConfig {
            return config
        }
        
        guard let path = Bundle.main.path(forResource: "GoogleOAuthConfig", ofType: "plist") else {
            print("[GoogleAuth] ❌ GoogleOAuthConfig.plist not found in bundle")
            configError = "OAuth configuration file not found"
            isConfigValid = false
            return nil
        }
        
        guard let data = FileManager.default.contents(atPath: path) else {
            print("[GoogleAuth] ❌ Failed to read GoogleOAuthConfig.plist")
            configError = "Failed to read OAuth configuration"
            isConfigValid = false
            return nil
        }
        
        do {
            let config = try PropertyListDecoder().decode(GoogleOAuthConfig.self, from: data)
            
            // Validate required fields
            guard !config.clientId.isEmpty else {
                print("[GoogleAuth] ❌ CLIENT_ID is empty")
                configError = "OAuth Client ID is missing"
                isConfigValid = false
                return nil
            }
            
            guard !config.redirectUri.isEmpty else {
                print("[GoogleAuth] ❌ REDIRECT_URI is empty")
                configError = "OAuth Redirect URI is missing"
                isConfigValid = false
                return nil
            }
            
            // Validate redirect URI format
            if !config.redirectUri.contains("://") {
                print("[GoogleAuth] ⚠️ Redirect URI may be malformed: \(config.redirectUri)")
            }
            
            print("[GoogleAuth] ✅ Configuration loaded successfully")
            print("[GoogleAuth] 📍 Redirect URI: \(config.redirectUri)")
            oauthConfig = config
            configError = nil
            isConfigValid = true
            return config
            
        } catch {
            print("[GoogleAuth] ❌ Failed to decode GoogleOAuthConfig.plist: \(error)")
            configError = "Invalid OAuth configuration format"
            isConfigValid = false
            return nil
        }
    }
    
    /// Returns the OAuth config or throws if invalid
    private func config() throws -> GoogleOAuthConfig {
        guard let config = loadConfig() else {
            throw GoogleAuthError.configNotFound
        }
        return config
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Validate config on init so isConfigValid is accurate
        print("[GoogleAuth] Initializing auth service...")
        _ = loadConfig()
        
        // Check if we have valid tokens on init
        Task {
            await checkSignInStatus()
        }
    }
    
    // MARK: - Public API
    
    /// Checks if user is signed in with valid token
    private func checkSignInStatus() async {
        isSignedIn = KeychainService.shared.getAccessToken() != nil
    }
    
    /// Handles OAuth redirect URL from external browser
    /// This is called by the .onOpenURL handler in GoFastApp
    func handleRedirect(_ url: URL) {
        print("[GoogleAuth] 📥 Received redirect URL: \(url)")
        
        // The ASWebAuthenticationSession handles the callback internally
        // This method is a no-op for now but can be used for logging or debugging
        // The actual callback handling happens in the session's completion handler
    }
    
    /// Starts OAuth2 authorization flow
    func signIn(presentationAnchor: ASPresentationAnchor? = nil) async throws -> GoogleAuthTokens {
        return try await withCheckedThrowingContinuation { continuation in
            signIn(presentationAnchor: presentationAnchor) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Non-async version for UI integration with window injection
    func signIn(
        presentationAnchor: ASPresentationAnchor? = nil,
        completion: @escaping (Result<GoogleAuthTokens, Error>) -> Void
    ) {
        // Validate configuration first
        guard isConfigValid else {
            let error = configError ?? "OAuth configuration is invalid"
            print("[GoogleAuth] ❌ Cannot start OAuth: \(error)")
            completion(.failure(GoogleAuthError.configNotFound))
            return
        }
        
        // Validate we can get the config
        let currentConfig: GoogleOAuthConfig
        do {
            currentConfig = try config()
        } catch {
            print("[GoogleAuth] ❌ Failed to load config: \(error)")
            completion(.failure(error))
            return
        }
        
        // Build authorization URL
        let state = UUID().uuidString
        let authURL: URL
        do {
            authURL = try buildAuthorizationURL(state: state)
        } catch {
            print("[GoogleAuth] ❌ Failed to build auth URL: \(error)")
            completion(.failure(error))
            return
        }
        
        // Store state for validation
        pendingExpectedState = state
        
        // Create web auth session
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "com.gofast"
        ) { [weak self] callbackURL, error in
            self?.handleCallback(
                callbackURL: callbackURL,
                error: error,
                expectedState: state
            )
        }
        
        // Use provided anchor or find key window safely
        let anchor: ASPresentationAnchor?
        if let providedAnchor = presentationAnchor {
            anchor = providedAnchor
            print("[GoogleAuth] Using provided presentation anchor")
        } else {
            anchor = findKeyWindow()
            print("[GoogleAuth] Using found key window")
        }
        
        // Validate we have a valid presentation anchor
        guard let validAnchor = anchor else {
            print("[GoogleAuth] ❌ No valid window found for OAuth presentation")
            completion(.failure(GoogleAuthError.noPresentationContext))
            return
        }
        
        print("[GoogleAuth] Window found: \(validAnchor)")
        print("[GoogleAuth] Window is key: \(validAnchor.isKeyWindow)")
        print("[GoogleAuth] Window frame: \(validAnchor.frame)")
        
        let presentationProvider = GooglePresentationAnchor(anchor: validAnchor)
        session.presentationContextProvider = presentationProvider
        session.prefersEphemeralWebBrowserSession = false
        
        self.webAuthSession = session
        
        // Start the session
        print("[GoogleAuth] Attempting to start session...")
        let started = session.start()
        if !started {
            print("[GoogleAuth] ❌ Failed to start ASWebAuthenticationSession")
            print("[GoogleAuth] Session state: \(session)")
            completion(.failure(GoogleAuthError.sessionStartFailed))
            return
        }
        
        print("[GoogleAuth] ✅ OAuth session started successfully")
    }
    
    /// Refreshes access token using refresh token with race condition protection
    func refreshAccessToken() async throws -> String {
        // Use actor to prevent concurrent refreshes
        return try await tokenRefreshActor.performRefresh { [weak self] in
            guard let self = self else {
                throw GoogleAuthError.serviceDeallocated
            }
            
            guard let refreshToken = KeychainService.shared.getRefreshToken() else {
                // Check if we expected to have a refresh token
                if KeychainService.shared.hasRefreshToken {
                    throw GoogleAuthError.refreshTokenRevoked
                } else {
                    throw GoogleAuthError.noRefreshToken
                }
            }
            
            let currentConfig = try self.config()
            
            let url = URL(string: currentConfig.tokenEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyParams = [
                "client_id": currentConfig.clientId,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ]
            request.httpBody = bodyParams.percentEncoded()
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // If refresh failed, sign out
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                    await self.signOut()
                }
                throw GoogleAuthError.tokenRefreshFailed
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            
            // Save new access token
            let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
            KeychainService.shared.saveAccessToken(tokenResponse.accessToken, expiry: expiry)
            
            // Update published property
            await MainActor.run {
                self.isSignedIn = true
            }
            
            return tokenResponse.accessToken
        }
    }
    
    /// Ensures a valid access token is available, refreshing if needed
    func ensureValidAccessToken() async throws -> String {
        if KeychainService.shared.isTokenValid(),
           let token = KeychainService.shared.getAccessToken() {
            return token
        }
        
        // Token expired or missing, refresh it
        return try await refreshAccessToken()
    }
    
    /// Signs out and clears all tokens
    func signOut() {
        KeychainService.shared.clearTokens()
        isSignedIn = false
    }
    
    // MARK: - Private Methods
    
    private func findKeyWindow() -> ASPresentationAnchor? {
        print("[GoogleAuth] Searching for presentation window...")
        
        // Method 1: Get the key window directly (works on iOS 13+)
        if let keyWindow = UIApplication.shared.keyWindow {
            print("[GoogleAuth] Found key window via UIApplication.shared.keyWindow")
            return keyWindow
        }
        
        // Method 2: Get the active window scene from connected scenes
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        
        print("[GoogleAuth] Found \(activeScenes.count) active window scenes")
        
        for windowScene in activeScenes {
            // Try to get the key window
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                print("[GoogleAuth] Found key window in active scene")
                return keyWindow
            }
            
            // Fallback: get first window
            if let firstWindow = windowScene.windows.first {
                print("[GoogleAuth] Found first window in active scene")
                return firstWindow
            }
        }
        
        // Method 3: Check all scenes (including inactive)
        print("[GoogleAuth] Checking all scenes...")
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            print("[GoogleAuth] Checking scene with activation state: \(windowScene.activationState)")
            
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                print("[GoogleAuth] Found key window in non-active scene")
                return keyWindow
            }
            
            if let firstWindow = windowScene.windows.first {
                print("[GoogleAuth] Found first window in non-active scene")
                return firstWindow
            }
        }
        
        // Method 4: Last resort - try to get any window from any scene
        print("[GoogleAuth] Last resort: getting any available window...")
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                print("[GoogleAuth] Found window - isHidden: \(window.isHidden), alpha: \(window.alpha)")
                if !window.isHidden && window.alpha > 0 {
                    return window
                }
            }
        }
        
        print("[GoogleAuth] ❌ Could not find any valid window for presentation")
        return nil
    }
    
    private func buildAuthorizationURL(state: String) throws -> URL {
        let currentConfig = try config()
        
        guard var components = URLComponents(string: currentConfig.authEndpoint) else {
            throw GoogleAuthError.configNotFound
        }
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: currentConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: currentConfig.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: currentConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent") // Force consent to get refresh token
        ]
        
        guard let url = components.url else {
            throw GoogleAuthError.configNotFound
        }
        
        return url
    }
    
    private func handleCallback(
        callbackURL: URL?,
        error: Error?,
        expectedState: String
    ) {
        if let error = error {
            completionHandler?(.failure(error))
            return
        }
        
        guard let url = callbackURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            completionHandler?(.failure(GoogleAuthError.invalidCallback))
            return
        }
        
        // Check for error
        if let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value {
            completionHandler?(.failure(GoogleAuthError.oauthError(errorDescription)))
            return
        }
        
        // Validate state
        guard let state = queryItems.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            completionHandler?(.failure(GoogleAuthError.invalidState))
            return
        }
        
        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            completionHandler?(.failure(GoogleAuthError.noAuthorizationCode))
            return
        }
        
        // Exchange code for tokens
        Task {
            do {
                let tokens = try await exchangeCodeForTokens(code: code)
                await MainActor.run {
                    self.isSignedIn = true
                }
                completionHandler?(.success(tokens))
            } catch {
                completionHandler?(.failure(error))
            }
        }
    }
    
    private func exchangeCodeForTokens(code: String) async throws -> GoogleAuthTokens {
        let currentConfig = try config()
        
        let url = URL(string: currentConfig.tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": currentConfig.clientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": currentConfig.redirectUri
        ]
        request.httpBody = bodyParams.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Calculate expiry
        let expiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        // Save tokens securely
        KeychainService.shared.saveAccessToken(tokenResponse.accessToken, expiry: expiry)
        
        // Save refresh token if provided (Google only sends it on first auth)
        if let refreshToken = tokenResponse.refreshToken {
            KeychainService.shared.saveRefreshToken(refreshToken)
        } else if !KeychainService.shared.hasRefreshToken {
            // No refresh token and we don't have one stored - this is problematic
            // but we'll still return the access token
            print("[GoogleAuth] Warning: No refresh token received from Google")
        }
        
        return GoogleAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiryDate: expiry
        )
    }
}

// MARK: - Presentation Context Provider

/// Custom presentation context provider that accepts any anchor
private class GooglePresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    let anchor: ASPresentationAnchor
    
    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return anchor
    }
}

// MARK: - Supporting Types

struct GoogleOAuthConfig: Codable {
    let clientId: String
    let redirectUri: String
    let authEndpoint: String
    let tokenEndpoint: String
    let scopes: [String]
    
    enum CodingKeys: String, CodingKey {
        case clientId = "CLIENT_ID"
        case redirectUri = "REDIRECT_URI"
        case authEndpoint = "AUTH_ENDPOINT"
        case tokenEndpoint = "TOKEN_ENDPOINT"
        case scopes = "SCOPES"
    }
}

struct GoogleAuthTokens {
    let accessToken: String
    let refreshToken: String?
    let expiryDate: Date
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum GoogleAuthError: Error, LocalizedError {
    case invalidCallback
    case invalidState
    case noAuthorizationCode
    case oauthError(String)
    case tokenExchangeFailed
    case tokenRefreshFailed
    case noRefreshToken
    case refreshTokenRevoked
    case serviceDeallocated
    case configNotFound
    case noPresentationContext
    case sessionStartFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid OAuth callback"
        case .invalidState:
            return "Security validation failed (state mismatch)"
        case .noAuthorizationCode:
            return "No authorization code received"
        case .oauthError(let description):
            return "OAuth error: \(description)"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .noRefreshToken:
            return "No refresh token available"
        case .refreshTokenRevoked:
            return "Refresh token was revoked - please sign in again"
        case .serviceDeallocated:
            return "Authentication service was deallocated"
        case .configNotFound:
            return "Google OAuth configuration not found"
        case .noPresentationContext:
            return "Unable to present OAuth window"
        case .sessionStartFailed:
            return "Failed to start OAuth session"
        }
    }
}

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
