//
//  LoginView.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//
// swiftlint:disable file_length

import SwiftUI
import FirebaseAuth
import Apollo
import AuthenticationServices
import CryptoKit

// MARK: Login View
struct LoginView: View {
    @StateObject private var authenticationManager = AuthenticationManager()

    var body: some View {
        NavigationView {
            VStack {
                HeartRateAnimation()

                formView
                    .padding()
                    .environmentObject(authenticationManager)
            }
            .background(Color.primaryBackgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Sign In")
                        .font(.title)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
            }
        }
    }

    @ViewBuilder private var formView: some View {
        switch authenticationManager.state {
        case .emailPrompt:
            EmailFormLoginView()
                .transition(.slideOut)

        case .passwordPrompt(let email):
            PasswordFormLoginView(email: email)
                .transition(.slideIn)

        case .registrationPrompt(let email):
            RegistrationFormLoginView(email: email)
                .transition(.slideIn)

        case .passwordRecoveryPrompt(let email):
            ForgotPasswordFormLoginView(email: email)
                .transition(.slideIn)
        }
    }
}

private enum LoginState {
    case emailPrompt
    case passwordPrompt(email: String)
    case registrationPrompt(email: String)
    case passwordRecoveryPrompt(email: String)
}

private class AuthenticationManager: ObservableObject {
    @Published var state = LoginState.emailPrompt
    @Published var reverseAnimation = false

    func update(state: LoginState) {
        withAnimation {
            self.state = state
        }
    }
}

// MARK: Email Form
private struct EmailFormLoginView: View {
    private static let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$")
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @State private var email = ""
    @State private var loading = false
    @State private var errorMessage = ""
    @State private var emailFieldError = false

    var body: some View {
        VStack {
            FormErrorMessage(errorMessage: errorMessage)

            FormField(placeholder: "Email Address", value: $email,
                      loading: loading, showError: emailFieldError,
                      keyboardType: .emailAddress,
                      textContentType: .emailAddress,
                      autocapitalization: .none,
                      disableAutocorrection: true)

            FormButton(text: "Sign In", loading: loading, blocked: loading) {
                var newErrorMessage = ""
                var emailFieldErrorNewState = false

                if email.isEmpty || !EmailFormLoginView.emailPredicate.evaluate(with: email) {
                    newErrorMessage = "Please, specify your email address."
                    emailFieldErrorNewState = true
                }

                if email.count > 200 {
                    newErrorMessage = "Your email address is too long."
                    emailFieldErrorNewState = true
                }

                DispatchQueue.main.async {
                    errorMessage = newErrorMessage
                    emailFieldError = emailFieldErrorNewState
                    loading = newErrorMessage.isEmpty
                }

                guard newErrorMessage.isEmpty else { return }

                ApiClient.shared.fetch(
                    query: CheckEmailReservedQuery(email: email),
                    cachePolicy: .fetchIgnoringCacheCompletely
                ) { result in
                    loading = false

                    switch result {
                    case .success(let response):
                        guard let emailReserved = response.data?.checkEmailReserved else {
                            errorMessage = "An error happend while checking if account exists. Please, try again later."
                            return
                        }

                        if emailReserved {
                            authenticationManager.update(state: .passwordPrompt(email: email))
                        } else {
                            authenticationManager.update(state: .registrationPrompt(email: email))
                        }
                        loading = false
                    case .failure:
                        errorMessage = "An exception happend while making request. "
                            + "Please, make sure that you have stable internet connection."
                    }
                }
            }
            
            AppleAuthenticationLoginView(loading: $loading, errorMessage: $errorMessage)
        }
    }
}

// MARK: Apple Authentication
private struct AppleAuthenticationLoginView: View {
    @Binding var loading: Bool
    @Binding var errorMessage: String
    @State private var nonce: String?
    
    var body: some View {
        SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
                
                let nonce = AppleAuthenticationLoginView.randomNonceString()
                self.nonce = nonce
                request.nonce = SHA256.hash(data: Data(nonce.utf8))
                    .compactMap { String(format: "%02x", $0) }
                    .joined()
            },
            onCompletion: handleAppleIdAuthentication
        )
        .frame(height: 50)
        .cornerRadius(3.0)
    }
    
    private func handleAppleIdAuthentication(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credentials = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "An error happened while trying to authenticate."
                return
            }
            
            guard let identityToken = credentials.identityToken else {
                print("Apple ID identity token is not present!")
                errorMessage = "An error happened while trying to authenticate."
                return
            }
            
            guard let idTokenString = String(data: identityToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(identityToken.debugDescription)")
                errorMessage = "An error happened while trying to authenticate."
                return
            }
            
            let firCredentials = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            
            loading = true
            Auth.auth().signIn(with: firCredentials) { _, error in
                loading = false
                
                if let error = error {
                    print("Error authenticating to firebase account: \(error.localizedDescription)")
                    errorMessage = "An error happened while trying to authenticate."
                    return
                }
            }
            
        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                guard authError.code != .canceled else { return }
            }
            
            print("Error authenticating using Apple ID: \(error.localizedDescription)")
            errorMessage = "An error happened while trying to authenticate."
        }
    }
    
    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                guard errorCode == errSecSuccess else {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                guard remainingLength != 0 else { return }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

// MARK: Password Form
private struct PasswordFormLoginView: View {
    let email: String
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var loading = false
    @State private var passwordFieldError = false

    var body: some View {
        VStack {
            HStack {
                FormErrorMessage(errorMessage: errorMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                Button {
                    authenticationManager.update(state: .passwordRecoveryPrompt(email: email))
                } label: {
                    Text("Forgot?")
                        .foregroundColor(.white)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .frame(idealWidth: 10, maxHeight: .infinity, alignment: .bottomTrailing)
                .disabled(loading)
            }

            PasswordFormField(placeholder: "Password", value: $password,
                              loading: loading, showError: passwordFieldError)

            FormButton(text: "Sign In", loading: loading, blocked: loading) {
                guard password.count >= 8 else {
                    DispatchQueue.main.async {
                        errorMessage = "You password is too small."
                        passwordFieldError = true
                    }
                    return
                }

                DispatchQueue.main.async {
                    loading = true
                    errorMessage = ""
                    passwordFieldError = false
                }

                Auth.auth().signIn(withEmail: email, password: password) { _, error in
                    loading = false

                    if let error = error as NSError? {
                        guard let errorCode = AuthErrorCode.Code(rawValue: error.code) else {
                            errorMessage = "An error happened while trying to authenticate!"
                            return
                        }

                        switch errorCode {
                        case .wrongPassword:
                            errorMessage = "You have typed wrong password!"
                            passwordFieldError = true
                        default:
                            break
                        }
                    }
                }
            }

            FormGoBackButton(blocked: loading)
        }
    }
}

// MARK: Registration Form
private struct RegistrationFormLoginView: View {
    let email: String
    @State private var displayName = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var loading = false
    @State private var errorFields: [Field] = []
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            FormErrorMessage(errorMessage: errorMessage)
            
            FormField(placeholder: "You name", value: $displayName,
                      loading: loading,
                      showError: errorFields.contains(Field.displayName),
                      keyboardType: .default, textContentType: .name,
                      autocapitalization: .words, disableAutocorrection: false)
            
            PasswordFormField(placeholder: "Your password", value: $password,
                              loading: loading, showError: errorFields.contains(Field.password),
                              textContentType: .newPassword)
            
            PasswordFormField(placeholder: "Confirm your password", value: $passwordConfirm,
                              loading: loading, showError: errorFields.contains(Field.passwordConfirm),
                              textContentType: .newPassword)
            
            FormButton(text: "Register", loading: loading, blocked: loading) {
                guard displayName.count > 2 else {
                    errorMessage = "Your name is too small."
                    errorFields = [Field.displayName]
                    return
                }
                
                guard password.count >= 8 else {
                    errorMessage = "Your password is too small."
                    errorFields = [Field.password]
                    return
                }
                
                guard password == passwordConfirm else {
                    errorMessage = "Your passwords do not match."
                    errorFields = [Field.password, Field.passwordConfirm]
                    return
                }
                
                loading = true
                errorMessage = ""
                errorFields = []
                
                Auth.auth().createUser(withEmail: email, password: password) { _, error in
                    loading = false
                    
                    guard error == nil else {
                        errorMessage = "Unknown error happened while trying to register new account. " +
                            "Please, check you internet connection."
                        return
                    }
                    
                    Task {
                        setUserDisplayName(tryNumber: 0)
                    }
                }
            }
            
            FormGoBackButton(blocked: loading)
        }
    }
    
    private enum Field {
        case displayName, password, passwordConfirm
    }
    
    private func setUserDisplayName(tryNumber: Int) {
        if tryNumber > 10 {
            return
        }
        
        ApiClient.shared.perform(mutation: UpdateUserDisplayNameMutation(newDisplayName: displayName)) { result in
            switch result {
            case .success(let data):
                if data.findErrorWith(path: "updateProfileDisplayName") != nil {
                    Task {
                        try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                        setUserDisplayName(tryNumber: tryNumber + 1)
                    }
                }
            case .failure:
                Task {
                    try await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                    setUserDisplayName(tryNumber: tryNumber + 1)
                }
            }
        }
    }
}

// MARK: Forgot Password Form
private struct ForgotPasswordFormLoginView: View {
    let email: String
    @State private var status: SendStatus?

    var body: some View {
        if let status = status {
            VStack {
                FormErrorMessage(errorMessage: status.message,
                                 color: status.dangerous ? .red : .white)

                if status.showRetryButton {
                    FormButton(text: "Retry", customIcon: "arrow.counterclockwise", loading: false, blocked: false) {
                        self.status = nil
                    }
                }

                FormGoBackButton(blocked: false)
            }
            .transition(.slideIn)
        } else {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                .transition(.slideIn)
                .task {
                    ApiClient.shared.perform(mutation: SendResetPasswordEmailMutation(email: email)) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let response):
                                if let sendStatus = response.data?.sendResetPasswordEmail {
                                    if sendStatus {
                                        status = SendStatus(message: "We just send an email to \(email). "
                                                            + "See recovery instruction there.")
                                    } else {
                                        status = SendStatus.defaultError
                                    }
                                } else {
                                    guard let error = response.findErrorWith(path: "sendResetPasswordEmail") else {
                                        status = SendStatus.defaultError
                                        return
                                    }

                                    switch error.code {
                                    case "user.not_found.by_email":
                                        let emailAddress = (error.extensions?["email"] as? String) ?? email
                                        status = SendStatus(
                                            message: "Error: user with email \(emailAddress) is not found!",
                                            dangerous: true
                                        )

                                    case "user.reset_password_request.already_made":
                                        status = SendStatus(
                                            message: "We've already send you email to reset your account password. "
                                                + "If you didn't receive it, please, try again later.",
                                            showRetryButton: true
                                        )

                                    default:
                                        status = SendStatus.defaultError
                                    }
                                }

                            case .failure:
                                status = SendStatus(
                                    message: "Failed to send recovery email. "
                                        + "Please, make sure that you have stable internet connection "
                                        + "and try again later.",
                                    dangerous: true,
                                    showRetryButton: true
                                )
                            }
                        }
                    }
                }
        }
    }

    private struct SendStatus {
        static let defaultError = SendStatus(
            message: "Failed to send recovery email. Please, try again later.",
            dangerous: true,
            showRetryButton: true
        )

        var message: String
        var dangerous: Bool = false
        var showRetryButton = false
    }
}

// MARK: Form Field
private struct FormField: View {
    let placeholder: String
    @Binding var value: String
    var loading: Bool = false
    var showError: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType = .name
    var autocapitalization: UITextAutocapitalizationType = .none
    var disableAutocorrection = true

    var body: some View {
        TextField(placeholder, text: $value)
            .foregroundColor(.white)
            .placeholder(when: value.isEmpty) {
                Text(placeholder).foregroundColor(.white)
            }
            .disableAutocorrection(disableAutocorrection)
            .keyboardType(keyboardType)
            .padding(.all)
            .disabled(loading)
            .frame(minHeight: 50)
            .warningBorder(when: showError, width: 3)
            .background(Color.loginFormButtonBackgrounColor)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .autocapitalization(autocapitalization)
            .cornerRadius(3.0)
    }
}

// MARK: Password Form Field
private struct PasswordFormField: View {
    let placeholder: String
    @Binding var value: String
    var loading: Bool = false
    var showError: Bool = false
    var textContentType: UITextContentType = .password

    var body: some View {
        SecureField(placeholder, text: $value)
            .foregroundColor(.white)
            .placeholder(when: value.isEmpty) {
                Text(placeholder).foregroundColor(.white)
            }
            .disableAutocorrection(true)
            .keyboardType(.asciiCapable)
            .padding(.all)
            .disabled(loading)
            .frame(minHeight: 50)
            .warningBorder(when: showError, width: 3)
            .background(Color.loginFormButtonBackgrounColor)
            .textContentType(textContentType)
            .keyboardType(.asciiCapable)
            .autocapitalization(.none)
            .cornerRadius(3.0)
    }
}

// MARK: Form Button
private struct FormButton: View {
    let text: String
    var direction: LayoutDirection = .leftToRight
    var customIcon: String?
    var loading: Bool = false
    var blocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            if !blocked {
                action()
            }
        } label: {
            HStack {
                switch direction {
                case .leftToRight:
                    Text(text).foregroundColor(.white)
                    Spacer()
                    icon
                case .rightToLeft:
                    icon
                    Spacer()
                    Text(text).foregroundColor(.white)
                @unknown default:
                    fatalError("Please, specify only 'leftToRight' or 'rightToLeft' direction")
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0)
        }
        .padding(.all)
        .background(Color.loginFormButtonBackgrounColor)
        .frame(minHeight: 50)
        .accentColor(.white)
        .cornerRadius(3.0)
    }

    @ViewBuilder private var icon: some View {
        if loading {
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
        } else {
            Image(systemName: iconSystemName)
        }
    }

    private var iconSystemName: String {
        if let customIcon = customIcon {
            return customIcon
        } else {
            return direction == .leftToRight ? "chevron.right" : "chevron.left"
        }
    }
}

// MARK: Form Go Back Button
private struct FormGoBackButton: View {
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    let blocked: Bool

    var body: some View {
        FormButton(text: "Go Back", direction: .rightToLeft, blocked: blocked) {
            authenticationManager.update(state: .emailPrompt)
        }
    }
}

// MARK: Form Error Message
private struct FormErrorMessage: View {
    let errorMessage: String
    var color: Color = .red

    var body: some View {
        Text(errorMessage)
            .foregroundColor(color)
            .font(.footnote)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }

    @ViewBuilder func warningBorder(when shouldShow: Bool, width: CGFloat) -> some View {
        if shouldShow {
            border(.red, width: width)
        } else {
            self
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()

        EmailFormLoginView()

        PasswordFormLoginView(email: "email@example.com")

        RegistrationFormLoginView(email: "email@example.com")

        ForgotPasswordFormLoginView(email: "email@example.com")
    }
}
