import UIKit
import Foundation

final class CustomModelsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var models: [AIModelConfig] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "自定义模型"
        view.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        load()
    }

    @objc private func addTapped() {
        let alert = UIAlertController(title: "新增模型", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "名称" }
        alert.addTextField { $0.placeholder = "URL"; $0.keyboardType = .URL }
        alert.addTextField { $0.placeholder = "API Key"; $0.isSecureTextEntry = false }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let url = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !url.isEmpty, !key.isEmpty else { return }
            var cfg = AIModelConfig(provider: .openAIStyle, modelName: name, thinking: true, apiKey: key, baseURL: url)
            self.models.append(cfg)
            self.save()
            self.tableView.reloadData()
        }))
        present(alert, animated: true)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "custom_models"),
           let arr = try? JSONDecoder().decode([AIModelConfig].self, from: data) {
            models = arr
        } else {
            models = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: "custom_models")
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let m = models[indexPath.row]
        cell.textLabel?.text = m.modelName
        cell.detailTextLabel?.text = nil
        return cell
    }
}
