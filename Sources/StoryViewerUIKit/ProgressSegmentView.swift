import UIKit

/// One top progress-bar segment: a track with a left-anchored fill that scales in X, mirroring
/// the Android View flavor's `fill.pivotX = 0f; fill.scaleX = fraction` approach.
final class ProgressSegmentView: UIView {
    private let fillView = UIView()
    private var anchorPointApplied = false

    var trackColor: UIColor = .clear {
        didSet { backgroundColor = trackColor }
    }

    var fillColor: UIColor = .white {
        didSet { fillView.backgroundColor = fillColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 1
        clipsToBounds = true
        fillView.transform = CGAffineTransform(scaleX: 0, y: 1)
        addSubview(fillView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        fillView.frame = bounds
        if !anchorPointApplied {
            fillView.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
            fillView.layer.position = CGPoint(x: 0, y: bounds.midY)
            fillView.frame = bounds
            anchorPointApplied = true
        }
    }

    /// Sets the fill fraction (0...1). When `duration` > 0, animates linearly to it; otherwise
    /// snaps instantly.
    func setFraction(_ value: Double, duration: TimeInterval) {
        fillView.layer.removeAllAnimations()
        let transform = CGAffineTransform(scaleX: CGFloat(value), y: 1)
        if duration > 0 {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear], animations: {
                self.fillView.transform = transform
            })
        } else {
            fillView.transform = transform
        }
    }
}
