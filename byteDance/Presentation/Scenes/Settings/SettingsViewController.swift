import UIKit

final class SettingsViewController: BaseViewController {
    private static let showArchivedKey = "session_list_show_archived"
    private let archivedLabel = UILabel()
    private let archivedSwitch = UISwitch()

    private let formStack = UIStackView()
    private let customEntryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"

        formStack.axis = .vertical
        formStack.spacing = 8
        formStack.translatesAutoresizingMaskIntoConstraints = false

        
        customEntryButton.setTitle("自定义模型", for: .normal)
        customEntryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        customEntryButton.contentHorizontalAlignment = .leading
        customEntryButton.addTarget(self, action: #selector(openCustomModels), for: .touchUpInside)
        formStack.addArrangedSubview(customEntryButton)
        view.addSubview(formStack)

        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        let archivedRow = UIStackView()
        archivedRow.axis = .horizontal
        archivedRow.alignment = .center
        archivedRow.spacing = 12
        archivedLabel.text = "隐私模式"
        archivedLabel.font = .systemFont(ofSize: 16)
        archivedSwitch.isOn = UserDefaults.standard.bool(forKey: Self.showArchivedKey)
        archivedSwitch.addTarget(self, action: #selector(onArchivedToggle), for: .valueChanged)
        archivedRow.addArrangedSubview(archivedLabel)
        archivedRow.addArrangedSubview(archivedSwitch)
        formStack.addArrangedSubview(archivedRow)
    }

    @objc private func onArchivedToggle() {
        UserDefaults.standard.set(archivedSwitch.isOn, forKey: Self.showArchivedKey)
    }

    @objc private func openCustomModels() {
        let vc = CustomModelsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
} 
