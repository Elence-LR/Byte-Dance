//
//  InputBarView+Image.swift
//  byteDance
//
//  Created by 李相瑜 on 2025/12/4.
//

import UIKit

extension InputBarView {
    func setupImageButton() {
        let imageBtn = UIButton(type: .system)
        imageBtn.setTitle("📷", for: .normal)
        imageBtn.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        imageBtn.addTarget(self, action: #selector(imageButtonTapped), for: .touchUpInside)

        addSubview(imageBtn)
        imageBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageBtn.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            imageBtn.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    @objc private func imageButtonTapped() {
        onImageButtonTapped?()
    }
}
