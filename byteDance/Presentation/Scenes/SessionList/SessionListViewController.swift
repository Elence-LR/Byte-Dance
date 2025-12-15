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
public final class SessionListViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let tableView = UITableView()
    private let repository = ChatRepository()
    private lazy var manage = ManageSessionUseCase(repository: repository)

//    private let service = DashScopeAdapter() // 桩服务，用于构造 ChatViewModel
    private let llmService: LLMServiceProtocol = LLMServiceRouter()
    
    // 搜索功能相关
    private let searchController = UISearchController(searchResultsController: nil)
    private var filteredSessions: [Session] = []
    
    // 归档视图切换
    private var showingArchived = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Sessions", comment: "")
        setupTable()
        setupSearchBar() // 新增：初始化搜索栏
        
        // 延迟设置导航栏按钮，解决约束冲突
        DispatchQueue.main.async {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addTapped))
            
            // 仅保留设置按钮，归档切换移至设置页
            let settingsButton = UIBarButtonItem(title: NSLocalizedString("Settings", comment: ""), style: .plain, target: self, action: #selector(self.settingsTapped))
            self.navigationItem.leftBarButtonItems = [settingsButton]
        }
        
        // 注册长按手势
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPress)
    }

    // 新增：初始化搜索栏
    private func setupSearchBar() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString("Search sessions...", comment: "")
        navigationItem.searchController = searchController
        definesPresentationContext = true
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
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showingArchived = UserDefaults.standard.bool(forKey: "session_list_show_archived")
        searchController.searchBar.text = ""
        updateSearchResults(for: searchController)
        tableView.reloadData()
    }

    // MARK: - 会话处理
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        
        // 新增：从过滤列表/归档列表获取会话
        let session = getCurrentSessions()[indexPath.row]
        showSessionActions(session: session, indexPath: indexPath)
    }
    
    // 显示会话操作菜单（新增置顶、归档功能）
    private func showSessionActions(session: Session, indexPath: IndexPath) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // 重命名会话
        alert.addAction(UIAlertAction(title: NSLocalizedString("Rename", comment: ""), style: .default) { [weak self] _ in
            self?.renameSession(session: session, indexPath: indexPath)
        })
        
        // 新增：置顶/取消置顶
        let pinTitle = session.isPinned ?
            NSLocalizedString("Unpin", comment: "") :
            NSLocalizedString("Pin", comment: "")
        alert.addAction(UIAlertAction(title: pinTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            if session.isPinned {
                self.manage.unpin(id: session.id)
            } else {
                self.manage.pin(id: session.id)
            }
            self.tableView.reloadData()
        })
        
        // 新增：归档/取消归档
        let archiveTitle = session.archived ?
            NSLocalizedString("Unarchive", comment: "") :
            NSLocalizedString("Archive", comment: "")
        alert.addAction(UIAlertAction(title: archiveTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            if session.archived {
                self.manage.unarchive(id: session.id)
            } else {
                self.manage.archive(id: session.id)
            }
            self.tableView.reloadData()
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
            self.tableView.reloadData()
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
        let session = getCurrentSessions()[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "")) { [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.deleteSession(session: session, indexPath: indexPath)
            completion(true)
        }
        
        let renameAction = UIContextualAction(style: .normal, title: NSLocalizedString("Rename", comment: "")) { [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            self.renameSession(session: session, indexPath: indexPath)
            completion(true)
        }
        renameAction.backgroundColor = .systemBlue
        
        // 侧滑添加归档/取消归档
        let archiveAction = UIContextualAction(style: .normal, title: session.archived ?
            NSLocalizedString("Unarchive", comment: "") :
            NSLocalizedString("Archive", comment: "")
        ) { [weak self] (_, _, completion) in
            guard let self = self else {
                completion(false)
                return
            }
            
            if session.archived {
                self.manage.unarchive(id: session.id)
            } else {
                self.manage.archive(id: session.id)
            }
            self.tableView.reloadData()
            completion(true)
        }
        archiveAction.backgroundColor = .systemOrange
        
        return UISwipeActionsConfiguration(actions: [deleteAction, archiveAction, renameAction])
    }
    
    // 支持滑动删除
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // 获取当前显示的会话列表（普通/归档/搜索过滤）
    private func getCurrentSessions() -> [Session] {
        if searchController.isActive, !searchController.searchBar.text!.isEmpty {
            return filteredSessions
        }
        return showingArchived ? manage.archivedSessions() : manage.sessions()
    }
    
    // 搜索功能实现
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text, !searchText.isEmpty else {
            filteredSessions.removeAll()
            tableView.reloadData()
            return
        }
        
        // 根据当前视图（普通/归档）过滤会话
        let baseSessions = showingArchived ? manage.archivedSessions() : manage.sessions()
        filteredSessions = baseSessions.filter {
            $0.title.lowercased().contains(searchText.lowercased())
        }
        
        tableView.reloadData()
    }

    private func navigateToChat(session: Session) {
        let sendUseCase = SendMessageUseCase(repository: repository, service: llmService)
        let vm = ChatViewModel(session: session, sendUseCase: sendUseCase, repository: repository)
        let vc = ChatViewController(viewModel: vm)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - UITableViewDataSource
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getCurrentSessions().count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath)
        let s = getCurrentSessions()[indexPath.row]
        
        // 新增：显示置顶标识
        if s.isPinned {
            cell.textLabel?.text = "📌 " + s.title
        } else {
            cell.textLabel?.text = s.title
        }
        
        // 优化：显示最后更新时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        let timeString = dateFormatter.string(from: s.updatedAt)
        cell.detailTextLabel?.text = "Messages: \(s.messages.count) • \(timeString)"
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = getCurrentSessions()[indexPath.row]
        
        // 导航到 ChatViewController
        navigateToChat(session: s)
    }
}
