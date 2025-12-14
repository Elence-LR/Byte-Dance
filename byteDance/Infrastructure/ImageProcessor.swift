//
//  ImageProcessor.swift
//  byteDance
//
//  Created by da A on 2025/12/4.
//

import UIKit

struct ImageProcessor {
    /// 智能压缩图片，平衡质量和大小
        static func optimizedJpegData(from image: UIImage,
                                     targetSize: CGSize? = nil,
                                     maxKB: Int = 300) -> Data? {
            // 1. 先调整尺寸（如果指定了目标尺寸）
            let resizedImage: UIImage
            if let target = targetSize {
                resizedImage = image.resized(to: target)
            } else {
                // 自动计算合适的尺寸（基于屏幕分辨率）
                let scale = UIScreen.main.scale
                let maxDimension = max(image.size.width, image.size.height)
                if maxDimension > 2048 { // 限制最大尺寸
                    let ratio = 2048 / maxDimension
                    let newSize = CGSize(width: image.size.width * ratio,
                                        height: image.size.height * ratio)
                    resizedImage = image.resized(to: newSize)
                } else {
                    resizedImage = image
                }
            }
            
            // 2. 再进行质量压缩（二分法优化压缩效率）
            let maxBytes = maxKB * 1024
            guard var data = resizedImage.jpegData(compressionQuality: 0.9) else { return nil }
            
            if data.count <= maxBytes {
                return data
            }
            
            // 二分法寻找最佳压缩质量
            var low: CGFloat = 0.0
            var high: CGFloat = 0.9
            var mid: CGFloat = 0.5
            
            for _ in 0..<6 { // 6次迭代足够精确
                mid = (low + high) / 2
                guard let newData = resizedImage.jpegData(compressionQuality: mid) else {
                    high = mid
                    continue
                }
                
                if newData.count > maxBytes {
                    high = mid
                } else {
                    low = mid
                    data = newData
                }
            }
            
            return data
        }
    }

    // UIImage扩展：调整尺寸
    extension UIImage {
        func resized(to size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
}
