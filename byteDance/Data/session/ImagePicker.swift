import SwiftUI
import UIKit

// 图片选择器UIKit封装
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImageData: Data?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary  // 从相册选择
        picker.delegate = context.coordinator
        picker.allowsEditing = true        // 允许裁剪
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // 选择图片后回调
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImageData = editedImage.pngData()
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImageData = originalImage.pngData()
            }
            parent.dismiss()
        }
        
        // 取消选择
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
