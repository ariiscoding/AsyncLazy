
import Foundation

/// A thread-safe lazy that can produce its value asynchronously or synchronously.
public final actor AsyncLazy<AssociatedType> where AssociatedType: Sendable {
    private let state: LazyState<AssociatedType>
    
    public init(_ factory: (@escaping @Sendable () async -> AssociatedType)) {
        self.state = .uninitiated(factory: factory)
    }
}
