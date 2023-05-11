
import ViewEnvironment

extension DescribedViewController {
    public enum Event {
        case viewWillLayoutSubviews
        case viewDidLayoutSubviews
        case viewWillAppear(animated: Bool)
        case viewDidAppear(animated: Bool)
        case didUpdateDescription(ViewControllerDescription)
    }
}
