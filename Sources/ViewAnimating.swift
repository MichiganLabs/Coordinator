import UIKit

public struct ViewAnimation {
    public struct Options {
        public let style: Style
        public let direction: Direction
        public let duration: TimeInterval

        public init(style: Style, direction: Direction = .left, duration: TimeInterval = 0.35) {
            self.style = style
            self.direction = direction
            self.duration = duration
        }
    }

    fileprivate enum Transition {
        case present
        case dismiss
    }

    public enum Style {
        case replace
        case swipe
    }

    public enum Direction {
        case left
        case right
        case up
        case down
    }
}

public protocol ViewAnimating {}

/// The `present` / `dismiss` methods intend to mimic the system `present` / `dismiss` methods but give you a little
/// more control for how the view controllers are animated on/off screen.
public extension ViewAnimating where Self: UIViewController & ViewCoordinating {
    func present(
        to newScreen: UIViewController,
        withOptions options: ViewAnimation.Options,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.animate(
            transition: .present,
            options: options,
            to: newScreen,
            completion: completion
        )
    }

    func dismiss(
        to newScreen: UIViewController,
        withOptions options: ViewAnimation.Options,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.animate(
            transition: .dismiss,
            options: options,
            to: newScreen,
            completion: completion
        )
    }

    private func animate(
        transition: ViewAnimation.Transition,
        options: ViewAnimation.Options,
        to newScreen: UIViewController,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let currentScreen = self.children.first else {
            self.replaceContents(with: newScreen)
            return
        }

        guard currentScreen != newScreen else {
            return
        }

        switch options.style {
        case .replace:
            self.animateReplace(fromScreen: currentScreen, toScreen: newScreen, withDuration: options.duration)
        case .swipe:
            self.animateSwipe(
                fromScreen: currentScreen,
                toScreen: newScreen,
                transition: transition,
                direction: options.direction,
                withDuration: options.duration
            )
        }
    }

    private func animateReplace(
        fromScreen: UIViewController,
        toScreen: UIViewController,
        withDuration duration: TimeInterval
    ) {
        self.addChild(toScreen)
        self.view.addSubview(toScreen.view)
        toScreen.view.transform = .identity
        toScreen.view.frame = self.view.bounds
        toScreen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toScreen.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.maxY)

        fromScreen.view.layer.cornerRadius = 0
        fromScreen.view.layer.masksToBounds = true

        UIView.animateKeyframes(
            withDuration: duration,
            delay: 0,
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) { [unowned fromScreen] in
                    var transform = CATransform3DIdentity
                    transform = CATransform3DScale(transform, 0.9, 0.9, 1.01)
                    fromScreen.view.layer.transform = transform

                    fromScreen.view.layer.cornerRadius = 6
                    fromScreen.view.alpha = 0.5
                }

                UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.75) { [unowned toScreen] in
                    toScreen.view.transform = CGAffineTransform.identity
                }
            },
            completion: { _ in
                self.remove(childViewController: fromScreen)
                toScreen.didMove(toParent: self)
                fromScreen.view.layer.cornerRadius = 0
                fromScreen.view.transform = CGAffineTransform.identity
                fromScreen.view.alpha = 1
            }
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func animateSwipe(
        fromScreen: UIViewController,
        toScreen: UIViewController,
        transition: ViewAnimation.Transition,
        direction: ViewAnimation.Direction,
        withDuration duration: TimeInterval
    ) {
        self.addChild(toScreen)

        self.view.addSubview(toScreen.view)
        toScreen.view.transform = .identity
        toScreen.view.frame = self.view.bounds
        toScreen.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if transition == .dismiss {
            self.view.bringSubviewToFront(fromScreen.view)
        } else {
            switch direction {
            case .left:
                toScreen.view.transform = CGAffineTransform(translationX: self.view.frame.maxX, y: 0)
            case .right:
                toScreen.view.transform = CGAffineTransform(translationX: -self.view.frame.maxX, y: 0)
            case .down:
                toScreen.view.transform = CGAffineTransform(translationX: 0, y: -self.view.frame.maxY)
            case .up:
                toScreen.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.maxY)
            }
        }

        let keyFrameAnimation: UIView.AnimationOptions
        if transition == .dismiss {
            keyFrameAnimation = .curveEaseIn
        } else {
            keyFrameAnimation = .curveEaseOut
        }

        UIView.animateKeyframes(
            withDuration: duration,
            delay: 0,
            options: UIView.KeyframeAnimationOptions(rawValue: keyFrameAnimation.rawValue),
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) { [unowned toScreen] in
                    if transition == .dismiss {
                        switch direction {
                        case .left:
                            fromScreen.view.transform = CGAffineTransform(translationX: -self.view.frame.maxX, y: 0)
                        case .right:
                            fromScreen.view.transform = CGAffineTransform(translationX: self.view.frame.maxX, y: 0)
                        case .down:
                            fromScreen.view.transform = CGAffineTransform(translationX: 0, y: self.view.frame.maxY)
                        case .up:
                            fromScreen.view.transform = CGAffineTransform(translationX: 0, y: -self.view.frame.maxY)
                        }
                    } else {
                        toScreen.view.transform = CGAffineTransform.identity
                    }
                }
            },
            completion: { _ in
                self.remove(childViewController: fromScreen)
                toScreen.didMove(toParent: self)
            }
        )
    }
}
