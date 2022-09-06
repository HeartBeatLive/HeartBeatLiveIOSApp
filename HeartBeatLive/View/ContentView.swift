//
//  ContentView.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var userAuthenticated = Auth.auth().currentUser != nil

    var body: some View {
        mainView
            .onAppear {
                Auth.auth().addStateDidChangeListener { _, user in
                    withAnimation {
                        userAuthenticated = user != nil
                    }
                }
            }
    }

    @ViewBuilder private var mainView: some View {
        if userAuthenticated {
            VStack {
                Text("Hello, \(Auth.auth().currentUser!.uid)")
                Button {
                    try? Auth.auth().signOut()
                } label: {
                    Text("Sign Out")
                }
            }
            .transition(.slideIn)
        } else {
            LoginView()
                .transition(.slideOut)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
