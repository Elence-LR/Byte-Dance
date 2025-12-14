//
//  InputBarView+Image.swift
//  byteDance
//
//  Created by 李相瑜 on 2025/12/4.
//

import UIKit
import SDWebImage

extension MessageCell {
    // 修改图片视图约束，使其能自适应内容
    func setupImageView(for attachment: MessageAttachment) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 保留最大尺寸限制，但允许缩小到图片实际尺寸
        imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
        imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true
        
        // 添加内容压缩阻力，防止图片被过度压缩
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        return imageView
    }

    // loadNetworkImage
    private func loadNetworkImage(imageView: UIImageView, url: URL) {
        imageView.sd_setImage(
            with: url,
            placeholderImage: UIImage(named: "placeholder"),
            options: [.scaleDownLargeImages, .continueInBackground]
        ) { [weak self] image, error, _, _ in
            if let error = error {
                print("图片加载失败: \(error.localizedDescription)")
                imageView.image = UIImage(named: "error_image")
            }
            
            // 无论成功失败都更新布局
            DispatchQueue.main.async {
                imageView.invalidateIntrinsicContentSize() // 刷新 intrinsic 尺寸
                imageView.superview?.setNeedsLayout()      // 标记父视图需要布局
                imageView.superview?.layoutIfNeeded()      // 立即更新布局
            }
        }
    }
    
    func loadImage(for imageView: UIImageView, from attachment: MessageAttachment) {
        // 显示占位图
        imageView.image = UIImage(named: "placeholder")
        
        if attachment.value.hasPrefix("data:image") {
            // 处理Base64图片
            loadBase64Image(imageView: imageView, base64String: attachment.value)
        } else if let url = URL(string: attachment.value) {
            // 处理网络图片
            loadNetworkImage(imageView: imageView, url: url)
        }
    }
    
    // 修改 loadBase64Image 方法
    private func loadBase64Image(imageView: UIImageView, base64String: String) {
        guard let base64Data = base64String.components(separatedBy: ",").last else { return }
        guard let data = Data(base64Encoded: base64Data) else { return }
        
        DispatchQueue.global().async {
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                    // 触发布局更新
                    imageView.invalidateIntrinsicContentSize()
                    imageView.superview?.setNeedsLayout()
                    imageView.superview?.layoutIfNeeded()
                }
            }
        }
    }
}
