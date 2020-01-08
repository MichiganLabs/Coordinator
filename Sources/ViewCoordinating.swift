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
