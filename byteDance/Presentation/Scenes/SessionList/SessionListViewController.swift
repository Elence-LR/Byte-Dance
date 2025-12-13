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

//    private let service = DashScopeAdapter() // 桩服务，用于构造 ChatViewModel
    private let llmService: LLMServiceProtocol = LLMServiceRouter()


    public override func viewDidLoad() {
           super.viewDidLoad()
           title = NSLocalizedString("Sessions", comment: "")
           setupTable()
           
           // 延迟设置导航栏按钮，解决约束冲突
           DispatchQueue.main.async {
               self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addTapped))
               let settingsButton = UIBarButtonItem(title: NSLocalizedString("Settings", comment: ""), style: .plain, target: self, action: #selector(self.settingsTapped))
               self.navigationItem.leftBarButtonItem = settingsButton
           }
           
           // 注册长按手势
           let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
           tableView.addGestureRecognizer(longPress)
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
        let vc = SettingsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    // MARK: - 会话处理
     @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
         guard gesture.state == .began else { return }
         
         let point = gesture.location(in: tableView)
         guard let indexPath = tableView.indexPathForRow(at: point) else { return }
         
         let session = manage.sessions()[indexPath.row]
         showSessionActions(session: session, indexPath: indexPath)
     }
     
     // 显示会话操作菜单
     private func showSessionActions(session: Session, indexPath: IndexPath) {
         let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
         
         // 重命名会话
         alert.addAction(UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default) { [weak self] _ in
             self?.renameSession(session: session, indexPath: indexPath)
         })
         
         // 删除会话
         alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { [weak self] _ in
             self?.deleteSession(session: session, indexPath: indexPath)
         })
         
         // 取消
         alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
         
         present(alert, animated: true)
     }
     
     // 重命名会话
     private func renameSession(session: Session, indexPath: IndexPath) {
         let alert = UIAlertController(title: NSLocalizedString("Rename Session", comment: ""), message: nil, preferredStyle: .alert)
         alert.addTextField { textField in
             textField.text = session.title
             textField.placeholder = NSLocalizedString("Enter new name", comment: "")
         }
         
         alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
         alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default) { [weak self] _ in
             guard let self = self,
                   let newTitle = alert.textFields?.first?.text,
                   !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
             
             // 更新会话标题
             self.manage.rename(id: session.id, title: newTitle)
             self.tableView.reloadRows(at: [indexPath], with: .automatic)
         })
         
         present(alert, animated: true)
     }
     
     // 删除会话
     private func deleteSession(session: Session, indexPath: IndexPath) {
         let alert = UIAlertController(
             title: NSLocalizedString("Delete Session", comment: ""),
             message: NSLocalizedString("Are you sure you want to delete this session?", comment: ""),
             preferredStyle: .alert
         )
         
         alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
         alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { [weak self] _ in
             guard let self = self else { return }
             
             // 删除会话
             self.manage.deleteSession(id: session.id)
             self.tableView.deleteRows(at: [indexPath], with: .automatic)
         })
         
         present(alert, animated: true)
     }

     // MARK: - UITableViewDelegate (侧滑删除)
     public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
         let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { [weak self] (_, _, completion) in
             guard let self = self else {
                 completion(false)
                 return
             }
             
             let session = self.manage.sessions()[indexPath.row]
             self.deleteSession(session: session, indexPath: indexPath)
             completion(true)
         }
         
         let renameAction = UIContextualAction(style: .normal, title: NSLocalizedString("Rename", comment: "")) { [weak self] (_, _, completion) in
             guard let self = self else {
                 completion(false)
                 return
             }
             
             let session = self.manage.sessions()[indexPath.row]
             self.renameSession(session: session, indexPath: indexPath)
             completion(true)
         }
         renameAction.backgroundColor = .systemBlue
         
         return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
     }
     
     // 支持滑动删除
     public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
         return true
     }
    private func navigateToChat(session: Session) {
        let sendUseCase = SendMessageUseCase(repository: repository, service: llmService)
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
