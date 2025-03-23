
import Foundation

/// A thread-safe lazy that can produce its value asynchronously or synchronously.
public final actor AsyncLazy<AssociatedType> where AssociatedType: Sendable {
    private var state: LazyState<AssociatedType>
    private var initializationTasks: [InitializationTask<AssociatedType>]
    
    public init(_ factory: (@escaping @Sendable () async -> AssociatedType), onInitialization initializationTask: InitializationTask<AssociatedType>? = nil) {
        self.state = .uninitiated(factory: factory)
        
        if let initializationTask {
            self.initializationTasks = [initializationTask]
        } else {
            self.initializationTasks = []
        }
    }
    
    public var value: AssociatedType {
        get async {
            switch state {
            case .uninitiated(factory: let factory):
                let task = Task<AssociatedType, Never> {
                    let value = await factory()
                    
                    self.initialize(value: value)
                    
                    return value
                }
                self.state = .initiating(task: task)
                return await task.value
            case .initiating(task: let task):
                return await task.value
            case .initiated(value: let value):
                return value
            }
        }
    }
    
    public func map<OutputType>(_ transform: @escaping @Sendable (AssociatedType) async -> OutputType, initializationTask: InitializationTask<OutputType>?) async -> AsyncLazy<OutputType> {
        .init({
            await transform(self.value)
        }, onInitialization: initializationTask)
    }
    
    public var isInitiated: Bool {
        get {
            if case .initiated(_) = self.state {
                return true
            }
            return false
        }
    }
    
    public func uponInitiation(task: InitializationTask<AssociatedType>) {
        switch state {
        case .uninitiated, .initiating:
            self.initializationTasks.append(task)
        case .initiated(value: let value):
            task.run(value)
        }
    }
}

// MARK: - Helpers

extension AsyncLazy {
    private func initialize(value: AssociatedType) {
        self.state = .initiated(value: value)
        
        // Run the initialization tasks
        for task in self.initializationTasks {
            task.run(value)
        }
        initializationTasks = []
    }
}
