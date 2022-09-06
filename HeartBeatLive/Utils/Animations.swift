//
//  Animations.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 05.09.2022.
//

import SwiftUI

extension AnyTransition {
    static let slideIn = asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )

    static let slideOut = asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .trailing)
    )
}
