import UIKit

/// White loading cover shown while Labs package-switch / first page load is pending.
final class LabsLaunchCover: UIViewController {

    private let displayName: String

    init(appName: String) {
        self.displayName = appName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        LaunchCoverLayout.install(on: view, appName: displayName, icon: AppIconResolver.image())
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) { return .darkContent }
        return .default
    }
}

// MARK: - Layout

private enum LaunchCoverLayout {
    static let iconSide: CGFloat = 80
    static let iconCornerFactor: CGFloat = 0.2237

    static func install(on root: UIView, appName: String, icon: UIImage?) {
        let iconView = makeIconView(image: icon)
        let titleLabel = makeTitleLabel(text: appName)
        let spinner = makeSpinner()

        root.addSubview(iconView)
        root.addSubview(titleLabel)
        root.addSubview(spinner)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -100),
            iconView.widthAnchor.constraint(equalToConstant: iconSide),
            iconView.heightAnchor.constraint(equalToConstant: iconSide),

            titleLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),

            spinner.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: 60),
        ])
    }

    private static func makeIconView(image: UIImage?) -> UIImageView {
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = iconSide * iconCornerFactor
        view.backgroundColor = .systemGray5
        return view
    }

    private static func makeTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func makeSpinner() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .systemGray
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        return spinner
    }
}

// MARK: - App icon

private enum AppIconResolver {
    static func image() -> UIImage? {
        if let named = UIImage(named: "AppIcon") { return named }
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let last = files.last
        else { return nil }
        return UIImage(named: last)
    }
}
