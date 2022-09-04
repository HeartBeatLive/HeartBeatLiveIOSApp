//
//  LoginView.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import SwiftUI

// MARK: Login View
struct LoginView: View {
    @StateObject private var authenticationManager = AuthenticationManager.shared

    var body: some View {
        NavigationView {
            VStack {
                HeartRateAnimation()

                formView
                    .padding()
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
        }
    }
}

private enum LoginState {
    case emailPrompt
    case passwordPrompt(email: String)
    case registrationPrompt(email: String)
}

private class AuthenticationManager: ObservableObject {
    public static let shared = AuthenticationManager()
    @Published var state = LoginState.emailPrompt
    @Published var reverseAnimation = false

    private init() {}

    func update(state: LoginState) {
        withAnimation {
            self.state = state
        }
    }
}

// MARK: Email Form
private struct EmailFormLoginView: View {
    private static let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$")
    @State private var email = ""
    @State private var loading = false
    @State private var errorMessage = ""
    @State private var emailFieldError = false

    var body: some View {
        VStack {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            FormField(placeholder: "Email Address", value: $email,
                      loading: loading, showError: emailFieldError,
                      keyboardType: .emailAddress,
                      textContentType: .emailAddress,
                      autocapitalization: .none,
                      disableAutocorrection: true)

            FormButton(text: "Sign In", loading: loading) {
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

                ApiClient.shared.fetch(query: CheckEmailReservedQuery(email: email)) { result in
                    loading = false

                    switch result {
                    case .success(let response):
                        guard let emailReserved = response.data?.checkEmailReserved else {
                            errorMessage = "An error happend while checking if account exists. Please, try again later."
                            return
                        }

                        if emailReserved {
                            AuthenticationManager.shared.update(state: .passwordPrompt(email: email))
                        } else {
                            AuthenticationManager.shared.update(state: .registrationPrompt(email: email))
                        }
                        loading = false
                    case .failure:
                        errorMessage = "An exception happend while making request. "
                            + "Please, make sure that you have stable internet connection."
                    }
                }
            }
        }
    }
}

// MARK: Password Form
private struct PasswordFormLoginView: View {
    let email: String

    var body: some View {
        FormGoBackButton()
    }
}

// MARK: Registration Form
private struct RegistrationFormLoginView: View {
    let email: String

    var body: some View {
        FormGoBackButton()
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

// MARK: Form Button
private struct FormButton: View {
    let text: String
    var direction: LayoutDirection = .leftToRight
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            Image(systemName: direction == .leftToRight ? "chevron.right" : "chevron.left")
        }
    }
}

// MARK: Form Go Back Button
private struct FormGoBackButton: View {
    var body: some View {
        FormButton(text: "Go Back", direction: .rightToLeft) {
            AuthenticationManager.shared.update(state: .emailPrompt)
        }
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
        if (shouldShow) {
            border(.red, width: width)
        } else {
            self
        }
    }
}

private extension AnyTransition {
    static let slideIn = asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )

    static let slideOut = asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .trailing)
    )
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()

        EmailFormLoginView()

        PasswordFormLoginView(email: "email@example.com")

        RegistrationFormLoginView(email: "email@example.com")
    }
}
