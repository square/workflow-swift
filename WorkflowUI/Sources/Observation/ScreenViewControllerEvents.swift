
import ViewEnvironment

extension ScreenViewController {
    public enum Event {
        case viewWillLayoutSubviews
        case viewDidLayoutSubviews
        case viewWillAppear(animated: Bool)
        case viewDidAppear(animated: Bool)
        case didUpdate(previousScreen: ScreenType, previousViewEnvironment: ViewEnvironment)
    }
}
