import Foundation

extension AsyncLazy {
    /**
     Provides synchronous, blocking access to the lazy value.
     
     - Important:
     - This method blocks the calling thread until the asynchronous factory completes.
     This can lead to potential deadlocks or poor performance if Swift concurrency
     tries to schedule the actor on the same thread.
     - Only use it to bridge legacy synchronous code that absolutely cannot be refactored
     to async/await. In modern Swift concurrency, prefer `await value`.
     
     - Returns: The lazy-initialized `AssociatedType` value, obtained by blocking the current thread.
     */
    public nonisolated func synchronousValue() -> AssociatedType {
        let semaphore = DispatchSemaphore(value: 0)
        var result: AssociatedType!
        
        Task(priority: .userInitiated) {
            let val = await self.value
            result = val
            semaphore.signal()
        }
        semaphore.wait()
        
        return result
    }
}
