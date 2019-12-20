import UIKit

protocol ViewCoordinating {}

/// There are times when you'll need to shove a view controller on screen. The methods defined in this extension
/// provide a way to `show` a child view controller within a view (which defaults to the presenting view controller's
/// `view`). You are also able to remove/replace child view controllers by using the respective methods.
///
/// Please note: These methods do NOT provide any animation. These methods will simply inject/remove a view controller
/// as a child and will not animate the process. If you want to animate this process, refer to the methods in the
/// second extension below.
extension ViewCoordinating where Self: UIViewController {
    func show(childViewController viewController: UIViewController) {
        self.show(childViewController: viewController, in: self.view)
    }

    func show(childViewController viewController: UIViewController, in container: UIView) {
        self.addChild(viewController)
        container.addSubview(viewController.view)
        viewController.view.frame = container.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.didMove(toParent: self)
    }

    func remove(childViewController viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    func replaceContents(with childViewController: UIViewController, in container: UIView? = nil) {
        // Remove previous child view controllers (if there are any)
        self.children.forEach {
            self.remove(childViewController: $0)
        }

        // Add new child view controller
        if let container = container {
            self.show(childViewController: childViewController, in: container)
        } else {
            self.show(childViewController: childViewController)
        }
    }
}

/// The `present` / `dismiss` methods intend to mimic the system `present` / `dismiss` methods but give you a little
/// more control for how the view controllers are animated on/off screen.
extension ViewCoordinating where Self: UIViewController {
    struct AnimationOptions {
        let style: AnimationStyle
        let direction: AnimationDirection
        let duration: TimeInterval

        public init(style: AnimationStyle, direction: AnimationDirection = .left, duration: TimeInterval = 0.35) {
            self.style = style
            self.direction = direction
            self.duration = duration
        }
    }

    private enum AnimationTransition {
        case present
        case dismiss
    }

    enum AnimationStyle {
        case replace
        case swipe
    }

    enum AnimationDirection {
        case left
        case right
        case up
        case down
    }

    func present(
        to newScreen: UIViewController,
        withOptions options: AnimationOptions,
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
        withOptions options: AnimationOptions,
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
        transition: AnimationTransition,
        options: AnimationOptions,
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
        transition: AnimationTransition,
        direction: AnimationDirection,
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
