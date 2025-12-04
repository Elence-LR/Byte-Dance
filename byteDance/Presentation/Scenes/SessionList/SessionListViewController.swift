//
//  SessionListViewController.swift
//  byteDance
//
//  Created by 刘锐 on 2025/12/4.
//
import UIKit

// SessionListViewController 只依赖 BaseVC 和数据协议
public final class SessionListViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let repository = ChatRepository()
    private lazy var manage = ManageSessionUseCase(repository: repository)

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

    // MARK: - 静态功能实现
    @objc private func addTapped() {
        let _ = manage.newSession(title: "New Session \(manage.sessions().count)")
        tableView.reloadData()
        print("New session created.")
    }
    
    @objc private func settingsTapped() {
        print("Settings button tapped.")
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
        print("Selected session: \(manage.sessions()[indexPath.row].title)")
    }
}
