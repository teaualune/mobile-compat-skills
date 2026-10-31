import UIKit

/// Hosts `content` in a centered column of at most `maxWidth` points on
/// regular-width windows (iPhone Duo inner display, iPad); `backgroundView` is
/// pinned to all edges so it paints under the bars and the status rail.
/// Compact width: the column is the full width.
///
/// Because the column is a child view controller, navigation and tab containers
/// above it still get their bars. The content controller keeps its own safe-area
/// handling (the container forwards `safeAreaInsets` by default).
final class DuoColumnContainerViewController: UIViewController {
    let content: UIViewController
    let backgroundView: UIView
    var maxWidth: CGFloat = 466          // outer display width; keep <= 480

    private var widthCap: NSLayoutConstraint!

    init(content: UIViewController, backgroundView: UIView = UIView()) {
        self.content = content
        self.backgroundView = backgroundView
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        content.didMove(toParent: self)

        widthCap = content.view.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth)
        let fullWidth = content.view.widthAnchor.constraint(equalTo: view.widthAnchor)
        fullWidth.priority = .defaultHigh   // wins on compact, loses to the cap on regular

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            widthCap, fullWidth,
        ])

        applySizeClass()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _) in
                self.applySizeClass()
            }
        }
    }

    // iOS < 17 fallback; harmless duplicate on 17+.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if previous?.horizontalSizeClass != traitCollection.horizontalSizeClass { applySizeClass() }
    }

    private func applySizeClass() {
        widthCap.isActive = traitCollection.horizontalSizeClass == .regular
    }
}
