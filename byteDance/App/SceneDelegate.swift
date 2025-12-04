//
//  SceneDelegate.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // 必须持有 window 和 coordinator，防止启动后立即释放导致白屏
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let coordinator = AppCoordinator(window: window)
        coordinator.start()
        self.window = window
        self.coordinator = coordinator
        window.makeKeyAndVisible()
    }
}
