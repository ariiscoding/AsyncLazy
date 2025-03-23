import Foundation

public struct InitializationTask<AssociatedType>: Sendable where AssociatedType: Sendable {
    public typealias Work = @Sendable (AssociatedType) async -> Void
    
    let work: Work
    let priority: TaskPriority?
    
    public init(work: @escaping Work, priority: TaskPriority?) {
        self.work = work
        self.priority = priority
    }
    
    @discardableResult
    func run(_ value: AssociatedType) -> Task<Void, Never> {
        Task(priority: priority) {
            await work(value)
        }
    }
}
