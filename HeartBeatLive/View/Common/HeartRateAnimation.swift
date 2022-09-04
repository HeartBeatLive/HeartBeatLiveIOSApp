//
//  HeartRateAnimation.swift
//  HeartBeatLive
//
//  Created by Nikita Ivchenko on 04.09.2022.
//

import SwiftUI
import Lottie

struct HeartRateAnimation: UIViewRepresentable {
    static let animationName = "HeartRateAnimation"
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        let animationView = AnimationView()
        animationView.animation = Animation.named(HeartRateAnimation.animationName)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = self.loopMode
        animationView.play()

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
    }
}

struct HeartRateAnimation_Previews: PreviewProvider {
    static var previews: some View {
        HeartRateAnimation()
            .previewLayout(.fixed(width: 300, height: 300))
    }
}
