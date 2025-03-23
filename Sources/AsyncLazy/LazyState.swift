
import Foundation

enum LazyState<AssociatedType> {
    case uninitiated(factory: (@Sendable () async -> AssociatedType))
    case created(value: AssociatedType)
}

extension LazyState: Sendable where AssociatedType: Sendable {}
