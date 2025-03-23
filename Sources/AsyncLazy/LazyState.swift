
import Foundation

/// Represents the various states an `AsyncLazy` value can occupy.
///
/// This enum tracks whether the value has been initialized yet, or if
/// it's currently in the process of initialization. By modeling these
/// states explicitly, we can prevent multiple concurrent initializations
/// and ensure thread-safe lazy loading of the value.
///
/// - Note: Conformance to `Sendable` ensures `LazyState` can be safely
///         passed across concurrency domains, but always access or
///         mutate it from an isolated context (e.g., an actor).
enum LazyState<AssociatedType> {
    
    /// Indicates the value has not yet been initialized.
    /// The `factory` closure holds the logic for producing the value.
    ///
    /// - Parameter factory: An async closure that produces the lazy value
    ///   upon first request.
    case uninitiated(factory: (@Sendable () async -> AssociatedType))
    
    /// The value is currently being initialized by a `Task`.
    /// Any additional callers that attempt to retrieve the value
    /// will await the same task instead of creating their own.
    ///
    /// - Parameter task: A `Task` that is actively creating the value.
    ///   Once this task completes, the state will transition to `.initiated`.
    ///
    /// - Note:
    /// This is needed to avoid the re-entrant race.
    case initiating(task: Task<AssociatedType, Never>)
    
    /// The value has been fully initialized and is now readily available
    /// to all callers without requiring further async work.
    ///
    /// - Parameter value: The fully initialized, cached `AssociatedType`.
    case initiated(value: AssociatedType)
}

extension LazyState: Sendable where AssociatedType: Sendable {}
