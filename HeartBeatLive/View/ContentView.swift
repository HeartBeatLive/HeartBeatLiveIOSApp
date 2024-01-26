//
//  ContentView.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var user = Auth.auth().currentUser
    @State private var reverseAnimation = false

    var body: some View {
        mainView
            .onAppear {
                Auth.auth().addStateDidChangeListener { _, user in
                    reverseAnimation = user == nil
                    withAnimation {
                        self.user = user
                    }
                    reverseAnimation = false
                }
            }
    }

    @ViewBuilder private var mainView: some View {
        if let user = self.user {
            VStack {
                Text("Hello, \(user.uid)")
                Button {
                    try? Auth.auth().signOut()
                } label: {
                    Text("Sign Out")
                }
            }
            .slideAnimation(reversed: reverseAnimation)
        } else {
            LoginView()
                .slideAnimation(reversed: reverseAnimation)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
