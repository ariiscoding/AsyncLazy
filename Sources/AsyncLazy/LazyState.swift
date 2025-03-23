
import Foundation

enum LazyState<AssociatedType> {
    case uninitiated(factory: (@Sendable () async -> AssociatedType))
    /// There's an active task initiating the value right now.
    ///
    /// This is needed to avoid the re-entrant race.
    case initiating(task: Task<AssociatedType, Never>)
    case initiated(value: AssociatedType)
}

extension LazyState: Sendable where AssociatedType: Sendable {}
