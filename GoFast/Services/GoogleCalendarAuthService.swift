//
//  GoogleCalendarAuthService.swift
//  GoFast
//
//  Manages Google OAuth2 authentication flow with automatic token refresh.
//  Uses ASWebAuthenticationSession for secure OAuth and Keychain for token storage.
//

import AuthenticationServices
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
    
    private var webAuthSession: ASWebAuthenticationSession?
    private var completionHandler: ((Result<GoogleAuthTokens, Error>) -> Void)?
    private let tokenRefreshActor = TokenRefreshActor()
    
    // MARK: - Configuration
    
    private var config: GoogleOAuthConfig {
        guard let path = Bundle.main.path(forResource: "GoogleOAuthConfig", ofType: "plist"),
              let data = FileManager.default.contents(atPath: path),
              let config = try? PropertyListDecoder().decode(GoogleOAuthConfig.self, from: data) else {
            fatalError("GoogleOAuthConfig.plist not found or invalid")
        }
        return config
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
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
    
    /// Starts OAuth2 authorization flow
    func signIn() async throws -> GoogleAuthTokens {
        return try await withCheckedThrowingContinuation { continuation in
            signIn { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Non-async version for UI integration with window injection
    func signIn(
        presentationAnchor: ASPresentationAnchor? = nil,
        completion: @escaping (Result<GoogleAuthTokens, Error>) -> Void
    ) {
        // Build authorization URL
        let state = UUID().uuidString
        let authURL = buildAuthorizationURL(state: state)
        
        // Store completion handler
        self.completionHandler = completion
        
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
        if let anchor = presentationAnchor {
            session.presentationContextProvider = GooglePresentationAnchor(anchor: anchor)
        } else {
            // Try to find key window safely (iOS 15+ approach)
            if let window = findKeyWindow() {
                session.presentationContextProvider = GooglePresentationAnchor(anchor: window)
            }
        }
        
        session.prefersEphemeralWebBrowserSession = false
        
        self.webAuthSession = session
        session.start()
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
            
            let url = URL(string: self.config.tokenEndpoint)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let bodyParams = [
                "client_id": self.config.clientId,
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
        // Modern iOS approach - safe for iOS 15+
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    private func buildAuthorizationURL(state: String) -> URL {
        var components = URLComponents(string: config.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent") // Force consent to get refresh token
        ]
        return components.url!
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
        let url = URL(string: config.tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": config.clientId,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectUri
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
