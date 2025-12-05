//
//  SessionListViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

// 为了编译和导航，从原始项目引入的必要依赖（ChatVM, ChatVC, UseCase等）
// 这些类在您的项目结构中都有对应的文件实现。
// 在这里我们使用原始的导入路径结构来引用它们。

// 桩代码：为了让 SessionListViewController 独立编译和导航


// SessionListViewController 只依赖 BaseVC 和数据协议
public final class SessionListViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let repository = ChatRepository()
    private lazy var manage = ManageSessionUseCase(repository: repository)

    private let service = OpenAIAdapter() // 桩服务，用于构造 ChatViewModel


    public override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Sessions", comment: "")
        setupTable()
        
        // ⭐️ 关键修复：延迟设置导航栏按钮，解决约束冲突
        DispatchQueue.main.async {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addTapped))
            let settingsButton = UIBarButtonItem(title: NSLocalizedString("Settings", comment: ""), style: .plain, target: self, action: #selector(self.settingsTapped))
            self.navigationItem.leftBarButtonItem = settingsButton
        }
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SessionCell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 功能实现 (新增会话并跳转)
    @objc private func addTapped() {
        // 创建新会话
        let newSession = manage.newSession(title: "New Session")
        tableView.reloadData()
        
        // 导航到 ChatViewController
        navigateToChat(session: newSession)
    }
    
    @objc private func settingsTapped() {
        // 实际应用中，这里会 push 到 SettingsViewController
        print("Navigating to Settings...")
    }
    
    private func navigateToChat(session: Session) {
        let sendUseCase = SendMessageUseCase(repository: repository, service: service)
        let vm = ChatViewModel(session: session, sendUseCase: sendUseCase, repository: repository)
        let vc = ChatViewController(viewModel: vm)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        manage.sessions().count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath)
        let s = manage.sessions()[indexPath.row]
        cell.textLabel?.text = s.title
        cell.detailTextLabel?.text = "Messages: \(s.messages.count)"
        return cell
    }
    
    // MARK: - UITableViewDelegate
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = manage.sessions()[indexPath.row]
        
        // 导航到 ChatViewController
        navigateToChat(session: s)
    }
}
