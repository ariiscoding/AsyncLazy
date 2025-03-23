import Foundation

/**
 A task encapsulating post-initialization work.
 
 This structure is typically used to schedule asynchronous work that should
 occur once the associated value is fully initialized. The task is provided
 the initialized value and can run additional operations asynchronously.
 
 - Note: `InitializationTask` instances can be appended to a lazy initializer
 (e.g., `AsyncLazy`) so that the work is executed automatically
 once the value is ready.
 
 - Parameters:
 - AssociatedType: The type of the value to be passed to the work closure.
 */
public struct InitializationTask<AssociatedType>: Sendable where AssociatedType: Sendable {
    /**
     A closure representing the asynchronous work to be performed once the
     associated value is initialized.
     
     - Parameter AssociatedType: The type of the value consumed by this closure.
     */
    public typealias Work = @Sendable (AssociatedType) async -> Void
    
    private let work: Work
    private let priority: TaskPriority?
    
    /**
     Creates a new `InitializationTask`.
     
     - Parameters:
     - work: An asynchronous closure that performs post-initialization work.
     - priority: An optional task priority used when the closure executes.
     */
    public init(work: @escaping Work, priority: TaskPriority?) {
        self.work = work
        self.priority = priority
    }
    
    /**
     Executes the stored work closure with the given value.
     
     - Parameter value: The value to pass into the work closure.
     - Returns: A `Task` that is executing the async work.
     */
    @discardableResult
    func run(_ value: AssociatedType) -> Task<Void, Never> {
        Task(priority: priority) {
            await work(value)
        }
    }
}
