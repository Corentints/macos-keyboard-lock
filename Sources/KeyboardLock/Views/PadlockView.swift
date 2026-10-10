import AppKit
import QuartzCore

/// Hand-drawn 2D padlock. Opening lifts the shackle, then swings it 180° around its right leg.
final class PadlockView: NSView {
    private enum Metrics {
        static let canvasSize = CGSize(width: 168, height: 112)

        static let bodyRect = CGRect(x: 44, y: 0, width: 80, height: 56)
        static let bodyCornerRadius: CGFloat = 14

        static let shackleSize = CGSize(width: 60, height: 56)
        static let shackleStroke: CGFloat = 9
        /// Closed position: the legs are hidden inside the body.
        static let shackleOrigin = CGPoint(x: 54, y: 36)
        static let shackleLift: CGFloat = 14
        /// Height of the free leg's tip once open.
        static let openFreeLegBottom: CGFloat = 1
    }

    private enum Animation {
        static let pathFrames = 40
        /// Share of the timeline spent lifting (opening) or lowering (closing).
        static let liftShare: CGFloat = 0.3
        static let openingDuration: CFTimeInterval = 0.9
        static let closingDuration: CFTimeInterval = 0.7
    }

    private let bodyLayer = CAShapeLayer()
    private let shackleLayer = CAShapeLayer()
    private(set) var isLocked = false

    private lazy var closedShacklePath = shacklePath(openingProgress: 0)
    private lazy var openShacklePath = shacklePath(openingProgress: 1)
    private let liftedTransform = CATransform3DMakeTranslation(0, Metrics.shackleLift, 0)

    override var intrinsicContentSize: NSSize { Metrics.canvasSize }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        configureLayers()
        updateColors()
        applyResting(locked: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    // MARK: State

    func setLocked(_ locked: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        guard locked != isLocked || !animated else {
            completion?()
            return
        }
        isLocked = locked
        applyResting(locked: locked)
        shackleLayer.removeAllAnimations()

        guard animated else {
            completion?()
            return
        }
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        addAnimations(locking: locked)
        CATransaction.commit()
    }

    private func applyResting(locked: Bool) {
        shackleLayer.path = locked ? closedShacklePath : openShacklePath
        shackleLayer.transform = locked ? CATransform3DIdentity : liftedTransform
    }

    // MARK: Layers

    private func configureLayers() {
        bodyLayer.path = makeBodyPath()
        bodyLayer.fillRule = .evenOdd // punches the keyhole out of the body

        shackleLayer.fillColor = nil
        shackleLayer.lineWidth = Metrics.shackleStroke
        shackleLayer.lineCap = .round
        shackleLayer.bounds = CGRect(origin: .zero, size: Metrics.shackleSize)
        shackleLayer.anchorPoint = .zero
        shackleLayer.position = Metrics.shackleOrigin

        layer?.addSublayer(shackleLayer) // behind the body, which hides the legs
        layer?.addSublayer(bodyLayer)
    }

    private func makeBodyPath() -> CGPath {
        let body = Metrics.bodyRect
        let path = CGMutablePath()
        path.addRoundedRect(in: body, cornerWidth: Metrics.bodyCornerRadius, cornerHeight: Metrics.bodyCornerRadius)
        path.addEllipse(in: CGRect(x: body.midX - 6, y: 30, width: 12, height: 12))
        path.addRoundedRect(in: CGRect(x: body.midX - 2.5, y: 14, width: 5, height: 20), cornerWidth: 2.5, cornerHeight: 2.5)
        return path
    }

    /// Opaque on purpose: system label colors turn translucent on top of glass.
    private func updateColors() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let color = (isDark ? NSColor(white: 0.96, alpha: 1) : NSColor(white: 0.1, alpha: 1)).cgColor
        bodyLayer.fillColor = color
        shackleLayer.strokeColor = color
    }

    // MARK: Shackle geometry

    /// U-shaped shackle seen after rotating `openingProgress` (0 closed, 1 fully open) around its right leg.
    /// The rotation is projected in 2D: x is squashed by cos(angle) while the stroke width stays constant,
    /// and the moving (left) leg shortens as it swings out.
    private func shacklePath(openingProgress: CGFloat) -> CGPath {
        let size = Metrics.shackleSize
        let halfStroke = Metrics.shackleStroke / 2
        let arcRadius = (size.width - Metrics.shackleStroke) / 2
        let arcCenterY = size.height - halfStroke - arcRadius
        let pivotX = size.width - halfStroke

        let path = CGMutablePath()
        path.move(to: CGPoint(x: halfStroke, y: Metrics.openFreeLegBottom * openingProgress))
        path.addLine(to: CGPoint(x: halfStroke, y: arcCenterY))
        path.addArc(center: CGPoint(x: size.width / 2, y: arcCenterY), radius: arcRadius,
                    startAngle: .pi, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: pivotX, y: 0))

        var squash = CGAffineTransform(translationX: pivotX, y: 0)
            .scaledBy(x: cos(.pi * openingProgress), y: 1)
            .translatedBy(x: -pivotX, y: 0)
        return path.copy(using: &squash) ?? path
    }

    // MARK: Animation

    private func addAnimations(locking: Bool) {
        let duration = locking ? Animation.closingDuration : Animation.openingDuration
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        // Opening: lift first, then swing. Closing: swing back first, then lower.
        let liftTimes: [CGFloat] = locking ? [0, 1 - Animation.liftShare, 1] : [0, Animation.liftShare, 1]
        let liftValues = locking
            ? [liftedTransform, liftedTransform, CATransform3DIdentity]
            : [CATransform3DIdentity, liftedTransform, liftedTransform]

        let lift = CAKeyframeAnimation(keyPath: "transform")
        lift.values = liftValues.map(NSValue.init(caTransform3D:))
        lift.keyTimes = liftTimes.map { NSNumber(value: Double($0)) }
        lift.timingFunctions = [ease, ease]
        lift.duration = duration

        let swing = CAKeyframeAnimation(keyPath: "path")
        swing.values = swingPaths(locking: locking)
        swing.calculationMode = .linear
        swing.duration = duration

        shackleLayer.add(lift, forKey: "lift")
        shackleLayer.add(swing, forKey: "swing")
    }

    private func swingPaths(locking: Bool) -> [CGPath] {
        let swingShare = 1 - Animation.liftShare
        return (0...Animation.pathFrames).map { frame in
            let time = CGFloat(frame) / CGFloat(Animation.pathFrames)
            let progress = locking
                ? 1 - Self.smoothstep(time / swingShare)
                : Self.smoothstep((time - Animation.liftShare) / swingShare)
            return shacklePath(openingProgress: progress)
        }
    }

    private static func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
