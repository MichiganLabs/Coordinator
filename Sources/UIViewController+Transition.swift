import UIKit

public extension UIViewController {
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