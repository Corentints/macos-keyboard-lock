import AppKit

protocol LockPanelDelegate: AnyObject {
    func lockPanel(_ panel: LockPanelView, didRequestLockFor duration: LockDuration)
    func lockPanelDidRequestUnlock(_ panel: LockPanelView)
    func lockPanel(_ panel: LockPanelView, didChangeMenuBarMode isEnabled: Bool)
}

/// The whole UI. Identical in the window and in the popover; only its host differs.
final class LockPanelView: NSStackView {
    enum Mode {
        case unlocked
        /// `remainingSeconds` is `nil` for an unlimited lock.
        case locked(remainingSeconds: Int?)
    }

    private enum Layout {
        static let width: CGFloat = 400
        static let spacing: CGFloat = 14
        static let spacingAfterPrimaryButton: CGFloat = 22
        static let primaryButtonWidth: CGFloat = 240
        static let insets = NSEdgeInsets(top: 0, left: 28, bottom: 24, right: 28)
    }

    weak var actionDelegate: LockPanelDelegate?

    /// Whether the app currently runs as a menu bar widget (drives the checkbox and the Quit button).
    var isMenuBarMode = false

    private let padlock = PadlockView()
    private var selectedDuration = LockDuration.default
    private var countdownLabel: NSTextField?
    private var heightConstraint: NSLayoutConstraint?
    private(set) var mode = Mode.unlocked

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .centerX
        spacing = Layout.spacing
        edgeInsets = Layout.insets
        widthAnchor.constraint(equalToConstant: Layout.width).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Content

    func show(_ mode: Mode) {
        self.mode = mode
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        countdownLabel = nil

        switch mode {
        case .unlocked:
            padlock.setLocked(false, animated: false)
            addArrangedSubview(padlock)
            addUnlockedContent()
        case .locked(let remainingSeconds):
            padlock.setLocked(true, animated: false)
            addArrangedSubview(padlock)
            addLockedContent(remainingSeconds: remainingSeconds)
        }
    }

    /// Pins the panel to the height of its tallest mode so hosts never resize on lock / unlock.
    /// Content stays anchored to the top, so the padlock keeps the same position in every mode.
    /// Call once the insets and `isMenuBarMode` are final.
    func fixHeightToTallestMode() {
        heightConstraint?.isActive = false
        let currentMode = mode

        let tallest = [Mode.unlocked, .locked(remainingSeconds: 0)].map { mode -> CGFloat in
            show(mode)
            return contentHeight
        }.max() ?? 0

        heightConstraint = heightAnchor.constraint(equalToConstant: tallest)
        heightConstraint?.isActive = true
        show(currentMode)
    }

    /// Sum of the rows, gaps and insets. `fittingSize` is not reliable here: it can undershoot the real layout.
    private var contentHeight: CGFloat {
        let rows = arrangedSubviews.reduce(0) { $0 + $1.fittingSize.height }
        let gaps = arrangedSubviews.dropLast().reduce(0) { total, view in
            let custom = customSpacing(after: view)
            return total + (custom == NSStackView.useDefaultSpacing ? spacing : custom)
        }
        return edgeInsets.top + edgeInsets.bottom + rows + gaps
    }

    func updateRemaining(_ seconds: Int) {
        countdownLabel?.stringValue = Self.format(seconds)
    }

    /// Plays the padlock animation in place, then calls `completion`.
    func animatePadlock(locked: Bool, completion: @escaping () -> Void) {
        padlock.setLocked(locked, animated: true, completion: completion)
    }

    private func addUnlockedContent() {
        addArrangedSubview(Self.label("Keyboard Lock", size: 20, weight: .semibold))
        addArrangedSubview(Self.label("All keys will be disabled", size: 12, weight: .regular, isSecondary: true))
        addArrangedSubview(makeDurationPicker())

        let lockButton = makeGlassButton("Lock", action: #selector(lockTapped))
        if #available(macOS 26.0, *) { lockButton.bezelColor = .controlAccentColor }
        lockButton.widthAnchor.constraint(equalToConstant: Layout.primaryButtonWidth).isActive = true
        addArrangedSubview(lockButton)
        setCustomSpacing(Layout.spacingAfterPrimaryButton, after: lockButton)

        let menuBarCheckbox = NSButton(checkboxWithTitle: "Show in menu bar",
                                       target: self, action: #selector(menuBarModeToggled(_:)))
        menuBarCheckbox.state = isMenuBarMode ? .on : .off
        menuBarCheckbox.controlSize = .small
        addArrangedSubview(menuBarCheckbox)

        if isMenuBarMode { addArrangedSubview(makeQuitButton()) }
    }

    private func addLockedContent(remainingSeconds: Int?) {
        addArrangedSubview(Self.label("Keyboard locked", size: 20, weight: .semibold))

        if let remainingSeconds {
            let label = NSTextField(labelWithString: Self.format(remainingSeconds))
            label.font = .monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
            label.alignment = .center
            countdownLabel = label
            addArrangedSubview(label)
        } else {
            addArrangedSubview(Self.label("All keys are disabled", size: 13, weight: .regular, isSecondary: true))
        }

        addArrangedSubview(makeGlassButton("Unlock", action: #selector(unlockTapped)))
    }

    // MARK: Actions

    @objc private func lockTapped() {
        actionDelegate?.lockPanel(self, didRequestLockFor: selectedDuration)
    }

    @objc private func unlockTapped() {
        actionDelegate?.lockPanelDidRequestUnlock(self)
    }

    @objc private func durationChanged(_ control: NSSegmentedControl) {
        selectedDuration = LockDuration.allCases[control.selectedSegment]
    }

    @objc private func menuBarModeToggled(_ checkbox: NSButton) {
        actionDelegate?.lockPanel(self, didChangeMenuBarMode: checkbox.state == .on)
    }

    // MARK: Components

    private func makeDurationPicker() -> NSSegmentedControl {
        let picker = NSSegmentedControl(labels: LockDuration.allCases.map(\.title),
                                        trackingMode: .selectOne,
                                        target: self,
                                        action: #selector(durationChanged(_:)))
        picker.segmentStyle = .capsule
        picker.controlSize = .large
        picker.selectedSegment = LockDuration.allCases.firstIndex(of: selectedDuration) ?? 0
        return picker
    }

    private func makeGlassButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.controlSize = .large
        button.keyEquivalent = "\r"
        if #available(macOS 26.0, *) { button.bezelStyle = .glass } else { button.bezelStyle = .rounded }
        return button
    }

    private func makeQuitButton() -> NSButton {
        let button = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        button.isBordered = false
        button.controlSize = .small
        button.contentTintColor = .secondaryLabelColor
        return button
    }

    private static func label(_ text: String, size: CGFloat, weight: NSFont.Weight, isSecondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = isSecondary ? .secondaryLabelColor : .labelColor
        label.alignment = .center
        return label
    }

    private static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
