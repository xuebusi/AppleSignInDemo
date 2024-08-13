//
//  AppleSignInView.swift
//  AppleSignInDemo
//
//  Created by shiyanjun on 2024/8/13.
//

import SwiftUI
import Security
import AuthenticationServices

/// Apple登录功能需要满足以下条件：
/// 1.开通苹果开发者计划；
/// 2.在Xcode的【Signing & Capabilities】设置栏点击【+Capability】按钮搜索并添加"Sign In With Apple"；
struct AppleSignInView: View {
    @StateObject private var userManager = UserManager()
    private var signInHandler: SignInWithAppleHandler

    init() {
        let userManager = UserManager()
        self._userManager = StateObject(wrappedValue: userManager)
        self.signInHandler = SignInWithAppleHandler(userManager: userManager)
    }

    var body: some View {
        VStack {
            if userManager.isLoggedIn {
                Text("欢迎回来，\(userManager.email ?? "")！")
                Button("登出") {
                    userManager.signOut()
                }
            } else {
                // 使用自定义按钮
                CustomAppleLoginButton(backgroundColor: .blue, textColor: .white) {
                    startSignInWithAppleFlow()
                }
                .frame(width: 200, height: 45)
            }
        }
        .environmentObject(userManager)
    }

    private func startSignInWithAppleFlow() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = signInHandler
        controller.performRequests()
    }
}

// 自定义Apple登录按钮
struct CustomAppleLoginButton: View {
    var backgroundColor: Color
    var textColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "applelogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 20)
                Text("通过Apple登录")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
        }
    }
}

/// - 登录授权
class SignInWithAppleHandler: NSObject, ASAuthorizationControllerDelegate {
    private var userManager: UserManager

    init(userManager: UserManager) {
        self.userManager = userManager
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email

            let fullNameString = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            userManager.signIn(userIdentifier: userIdentifier, email: email, fullName: fullNameString)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("授权失败: \(error.localizedDescription)")
    }
}

/// 用户信息管理类
class UserManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var email: String?
    @Published var fullName: String?

    init() {
        /// 启动时从本地读取登录信息
        if let _ = KeychainHelper.read(for: "userIdentifier") {
            isLoggedIn = true
            email = KeychainHelper.read(for: "email")
            fullName = KeychainHelper.read(for: "fullName")
        }
    }

    /// 保存登录信息到本地
    func signIn(userIdentifier: String, email: String?, fullName: String?) {
        print(">>> UserID:\(userIdentifier)")
        print(">>> Email:\(String(describing: email))")
        print(">>> FullName:\(String(describing: fullName))")
        
        KeychainHelper.save(userIdentifier, for: "userIdentifier")
        
        if let localEmail = KeychainHelper.read(for: "email") {
            print("本地Email:\(localEmail)")
            self.email = localEmail
        } else {
            if let email = email {
                KeychainHelper.save(email, for: "email")
                self.email = email
            }
        }
        
        if let localFullName = KeychainHelper.read(for: "fullName") {
            print("本地FullName:\(localFullName)")
            self.fullName = localFullName
        } else {
            if let fullName = fullName, fullName != "" {
                KeychainHelper.save(fullName, for: "fullName")
                self.fullName = fullName
            }
        }

        isLoggedIn = true
    }

    /// 退出登录
    func signOut() {
        /// - 退出登录时，删除本地用户ID但不删除邮箱（因为Apple登录API只在首次登录时才返回邮箱）
        KeychainHelper.delete(for: "userIdentifier")
        
        //KeychainHelper.delete(for: "fullName")
        //KeychainHelper.delete(for: "email")

        isLoggedIn = false
        email = nil
        fullName = nil
    }
}

/// 加密工具
struct KeychainHelper {
    static func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("无法保存数据: \(status)")
        }
    }

    static func read(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) {
            return value
        } else {
            return nil
        }
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}

#Preview {
    AppleSignInView()
        .preferredColorScheme(.dark)
}

