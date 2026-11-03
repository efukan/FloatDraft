import Observation
import ServiceManagement

/// The subset of `SMAppService` used here; a protocol so tests can substitute a fake.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Launch at login via `SMAppService.mainApp`. Off until the user turns it on (D5, Guideline 2.4.5):
/// nothing here ever registers on its own.
@Observable
final class LoginItemController {
    private(set) var status: SMAppService.Status
    private(set) var lastError: String?
    @ObservationIgnored private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        status = service.status
    }

    /// Registered, including while waiting for approval in System Settings.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    /// The user can change this in System Settings at any time.
    func refresh() {
        status = service.status
    }
}
