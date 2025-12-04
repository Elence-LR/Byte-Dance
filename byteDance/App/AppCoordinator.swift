//
//  AppCoordinator.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private let navigationController = UINavigationController()

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        let sessionVC = SessionListViewController()
        navigationController.view.backgroundColor = .systemBackground
        navigationController.setViewControllers([sessionVC], animated: false)
        window.rootViewController = navigationController
    }
}
