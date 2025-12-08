import UIKit

final class SettingsViewController: BaseViewController {
    private let toggle = UISwitch()
    private let label = UILabel()
    private let stack = UIStackView()
    private static let key = "test_mode_enabled"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        label.text = "测试模式（固定模板回复）"
        label.font = .systemFont(ofSize: 16)
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(toggle)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
        toggle.isOn = UserDefaults.standard.bool(forKey: Self.key)
        toggle.addTarget(self, action: #selector(onToggle), for: .valueChanged)
    }

    @objc private func onToggle() {
        UserDefaults.standard.set(toggle.isOn, forKey: Self.key)
    }
}
