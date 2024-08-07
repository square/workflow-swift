import UIKit
import Workflow
import WorkflowUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let root = WorkflowHostingController(
            workflow: MultiCounterWorkflow().mapRendering(MultiCounterScreen.init)
        )
        root.view.backgroundColor = .systemBackground

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = root
        window?.makeKeyAndVisible()

        return true
    }
}
