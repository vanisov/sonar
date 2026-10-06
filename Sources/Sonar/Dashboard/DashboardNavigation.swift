import SwiftUI

/// Which section the dashboard shows; the panel's cards set it before opening the window.
@MainActor @Observable final class DashboardNavigation {
    static let shared = DashboardNavigation()
    var section: DashboardSection? = .overview {
        didSet { if let section { UserDefaults.standard.set(section.rawValue, forKey: Prefs.dashboardLastSection) } }
    }
    var query = ""
    var diskCleanUp = false  // the Disk page's Clean Up tab
}
