//
//  KeychainService.swift
//  GoFast
//
//  Secure storage for OAuth tokens and credentials.
//  Uses iOS Keychain for secure, encrypted storage.
//

import Security
import Foundation

/// Secure storage for OAuth tokens
class KeychainService {
    static let shared = KeychainService()
    
    private let accessTokenKey = "com.gofast.google.accessToken"
    private let refreshTokenKey = "com.gofast.google.refreshToken"
    private let expiryKey = "com.gofast.google.tokenExpiry"
    private let hasRefreshTokenKey = "com.gofast.google.hasRefreshToken"
    
    // MARK: - Token Storage
    
    @discardableResult
    func saveAccessToken(_ token: String, expiry: Date) -> Bool {
        return save(token.data(using: .utf8)!, service: accessTokenKey) &&
               save(String(expiry.timeIntervalSince1970).data(using: .utf8)!, service: expiryKey)
    }
    
    @discardableResult
    func saveRefreshToken(_ token: String) -> Bool {
        let success = save(token.data(using: .utf8)!, service: refreshTokenKey)
        if success {
            // Persist flag that we have a refresh token
            UserDefaults.standard.set(true, forKey: hasRefreshTokenKey)
        }
        return success
    }
    
    func getAccessToken() -> String? {
        guard let data = retrieve(service: accessTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func getRefreshToken() -> String? {
        guard let data = retrieve(service: refreshTokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Returns true if we previously stored a refresh token
    var hasRefreshToken: Bool {
        UserDefaults.standard.bool(forKey: hasRefreshTokenKey)
    }
    
    func getTokenExpiry() -> Date? {
        guard let data = retrieve(service: expiryKey),
              let timestampString = String(data: data, encoding: .utf8),
              let timestamp = Double(timestampString) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    func isTokenValid() -> Bool {
        guard let expiry = getTokenExpiry() else { return false }
        // 5 minute buffer before expiry
        return expiry > Date().addingTimeInterval(300)
    }
    
    func clearTokens() {
        delete(service: accessTokenKey)
        delete(service: refreshTokenKey)
        delete(service: expiryKey)
        UserDefaults.standard.removeObject(forKey: hasRefreshTokenKey)
    }
    
    // MARK: - Keychain Operations
    
    private func save(_ data: Data, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GoFast",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func retrieve(service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GoFast",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result as? Data
    }
    
    private func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "GoFast"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
