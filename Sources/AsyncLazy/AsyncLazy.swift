//
//  AsyncLazy.swift
//
//  MIT License
//
//  Copyright (c) 2025 Ari He
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/**
 A thread-safe lazy container that defers creation of its value until requested.
 Once initialization begins, all concurrent requests for the value will wait
 on the same task, ensuring only one factory call is executed.
 
 - Note: This actor safely manages concurrent access to its state and ensures
 each value is created once.
 
 - Parameters:
 - AssociatedType: The type of the value to be produced.
 */
public final actor AsyncLazy<AssociatedType> where AssociatedType: Sendable {
    private var state: LazyState<AssociatedType>
    private var initializationTasks: [InitializationTask<AssociatedType>]
    
    /**
     Creates a new `AsyncLazy` actor instance.
     
     - Parameters:
     - factory: An async closure that produces the value when first requested.
     - initializationTask: An optional task to run once the value has been created.
     */
    public init(_ factory: (@escaping @Sendable () async -> AssociatedType), onInitialization initializationTask: InitializationTask<AssociatedType>? = nil) {
        self.state = .uninitiated(factory: factory)
        
        if let initializationTask {
            self.initializationTasks = [initializationTask]
        } else {
            self.initializationTasks = []
        }
    }
    
    /**
     The lazily loaded value. Accessing this property will trigger the factory
     if the value has not yet been created. When multiple callers concurrently
     request the value, only one factory call will be made.
     
     - Returns: The lazily initialized `AssociatedType` value.
     */
    public var value: AssociatedType {
        get async {
            switch state {
            case .uninitiated(factory: let factory):
                let task = Task<AssociatedType, Never> {
                    let value = await factory()
                    
                    await self.initialize(value: value)
                    
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
    
    /**
     Transforms the already-lazy value into another `AsyncLazy`.
     
     - Parameters:
     - transform: A closure to convert the current value to a new type.
     - initializationTask: An optional task to run once the transformed value is created.
     - Returns: A new `AsyncLazy` instance that depends on the current one.
     */
    public func map<OutputType>(_ transform: @escaping @Sendable (AssociatedType) async -> OutputType, initializationTask: InitializationTask<OutputType>?) async -> AsyncLazy<OutputType> {
        .init({
            await transform(self.value)
        }, onInitialization: initializationTask)
    }
    
    /**
     Indicates if the lazy value has already been created.
     
     - Returns: `true` if the value has been initialized, otherwise `false`.
     */
    public var isInitiated: Bool {
        get {
            if case .initiated(_) = self.state {
                return true
            }
            return false
        }
    }
    
    /**
     Registers a task to be performed once the value is initialized.
     If the value is already initialized, the task is invoked immediately.
     
     - Parameter task: A closure that runs after the value is created.
     */
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
    /**
     Completes the initialization state with the provided value.
     Invokes all pending initialization tasks.
     
     - Parameter value: The value created by the factory.
     */
    private func initialize(value: AssociatedType) async {
        self.state = .initiated(value: value)
        
        // Run the initialization tasks
        for task in self.initializationTasks {
            task.run(value)
        }
        initializationTasks = []
    }
}
