//
//  ImageProcessor.swift
//  byteDance
//
//  Created by da A on 2025/12/4.
//

import UIKit

struct ImageProcessor {
    /// 将图片压缩为指定 KB 以下的 JPEG 数据
    static func jpegData(from image: UIImage, maxKB: Int = 300) -> Data? {
        var compression: CGFloat = 0.9
        let maxBytes = maxKB * 1024

        guard var data = image.jpegData(compressionQuality: compression) else { return nil }

        while data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            if let newData = image.jpegData(compressionQuality: compression) {
                data = newData
            }
        }
        return data
    }
}
