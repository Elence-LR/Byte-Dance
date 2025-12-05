//
//  ChatViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit
import PhotosUI

public final class ChatViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let inputBar = InputBarView()
    private let viewModel: ChatViewModel

    private let config = AIModelConfig(modelName: "deepseek-chat", apiKey: "sk-24696f0c8e1f490386d913ef1caba425") // 使用默认配置

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.session.title
        setupTable()
        setupInput()
        
        // 消息更新回调，用于刷新 UI
        viewModel.onNewMessage = { [weak self] _ in
            self?.tableView.reloadData()
            // 滚动到底部
            if let count = self?.viewModel.messages().count, count > 0 {
                self?.tableView.scrollToRow(at: IndexPath(row: count - 1, section: 0), at: .bottom, animated: true)
            }
        }
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        // 移除分隔线，更像聊天 UI
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        
        // 约束设置在 setupInput 中完成
    }

    private func setupInput() {
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // TableView 顶部到安全区域
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // InputBar 位于底部安全区域
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // TableView 底部连接到 InputBar 顶部
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
        
        // 文本发送按钮逻辑：调用 ViewModel 发送消息
        inputBar.onSend = { [weak self] text in
            guard let self else { return }
            self.viewModel.send(text: text, config: self.config)
        }
        
        //李相瑜新增：图片按钮点击 -> 弹 picker
        inputBar.onImageButtonTapped = { [weak self] in
            guard let self = self else { return }
            var pickerConfig = PHPickerConfiguration()
            pickerConfig.filter = .images
            pickerConfig.selectionLimit = 1
            let picker = PHPickerViewController(configuration: pickerConfig)
            picker.delegate = self
            self.present(picker, animated: true)
        }
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.messages().count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        let message = viewModel.messages()[indexPath.row]
        cell.configure(with: message)
        return cell
    }
}

// 李相瑜新增：MARK: - 图片选择器回调
extension ChatViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self = self else { return }
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    self.viewModel.sendImage(image)
                }
            }
        }
    }
}

