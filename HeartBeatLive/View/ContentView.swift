//
//  ContentView.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import SwiftUI

struct ContentView: View {
    @State private var email = ""
    @State private var resultMessage: String = ""

    var body: some View {
        Form {
            Section("Check if email is reserved") {
                TextField("Email address", text: $email)
                Text(resultMessage)
                Button {
                    ApiClient.shared.fetch(query: CheckEmailReservedQuery(email: email)) { result in
                        switch result {
                        case .success(let result):
                            guard let emailReserved = result.data?.checkEmailReserved else {
                                resultMessage = "An error happened while trying to check if email is reserved"
                                return
                            }
                            resultMessage = emailReserved ? "Email is reserved" : "Email is not reserved"
                        case .failure(let error):
                            resultMessage = "An error happened: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    Text("Check")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
