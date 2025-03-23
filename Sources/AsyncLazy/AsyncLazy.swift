
import Foundation

/// A thread-safe lazy that can produce its value asynchronously or synchronously.
public final actor AsyncLazy<AssociatedType> where AssociatedType: Sendable {
    private var state: LazyState<AssociatedType>
    
    public init(_ factory: (@escaping @Sendable () async -> AssociatedType)) {
        self.state = .uninitiated(factory: factory)
    }
    
    public var value: AssociatedType {
        get async {
            switch state {
            case .uninitiated(factory: let factory):
                let value = await factory()
                self.state = .initiated(value: value)
                
                return value
            case .initiated(value: let value):
                return value
            }
        }
    }
}
