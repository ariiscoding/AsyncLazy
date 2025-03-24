import Testing
import Foundation
@testable import AsyncLazy

// MARK: - A small actor for concurrency-safe counting
actor Counter {
    private var _count = 0
    
    func increment() {
        _count += 1
    }
    
    func value() -> Int {
        _count
    }
}

struct AsyncLazyTests {
    
    /// Ensures that an `AsyncLazy` is not marked as initiated until the value is requested.
    @Test
    func testInitAndIsInitiated() async {
        let lazy = AsyncLazy {
            42
        }
        
        #expect(await lazy.isInitiated == false, "Should not be initiated before value is accessed.")
        
        let value = await lazy.value
        #expect(value == 42, "The value should be 42 once accessed.")
        
        #expect(await lazy.isInitiated, "Should be marked as initiated after requesting value.")
    }
    
    /// Calls `value` multiple times and ensures the factory is invoked only once.
    @Test
    func testValueMultipleCalls() async {
        let counter = Counter()
        
        let lazy = AsyncLazy {
            // Increment the actor’s count, safely
            await counter.increment()
            // Simulate some async delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            return UUID().uuidString
        }
        
        // Call value multiple times
        let value1 = await lazy.value
        let value2 = await lazy.value
        
        // Should be the same
        #expect(value1 == value2, "All calls should get the same result.")
        
        // Because we only want one factory invocation, check the final count
        #expect(await counter.value() == 1, "Factory should only be called once.")
    }
    
    /// Tests registering an initialization task to confirm it fires exactly once.
    @Test
    func testUponInitiation() async {
        let asyncWaiter = AsyncWaiter()
        
        let lazy = AsyncLazy {
            99
        }
        
        // Add a task that will run once the value is created
        await lazy.uponInitiation(task: .init(work: { val in
            #expect(val == 99, "Initialization task received the correct value.")
            await asyncWaiter.signal()
        }, priority: nil))
        
        // Trigger initialization
        let v = await lazy.value
        #expect(v == 99, "Main returned value should be 99.")
        
        // Wait for the init task to signal
        await asyncWaiter.wait()
    }
    
    /// Tests the `map` function, verifying lazy initialization of the mapped value.
    @Test
    func testMap() async {
        let lazyInt = AsyncLazy {
            5
        }
        
        let mappedLazy = await lazyInt.map({ intVal in
            "Transformed to: \(intVal)"
        }, initializationTask: nil)
        
        let strValue = await mappedLazy.value
        #expect(strValue == "Transformed to: 5")
        
        #expect(await lazyInt.isInitiated, "Base lazy should be initiated after value retrieval.")
        #expect(await mappedLazy.isInitiated, "Mapped lazy should also be initiated once accessed.")
    }
    
    /// Tests concurrency with multiple async callers, ensuring only one factory call occurs.
    @Test
    func testConcurrentAccess() async {
        let concurrentCalls = 50
        let counter = Counter()
        
        let lazy = AsyncLazy {
            await counter.increment() // concurrency-safe increment
            try? await Task.sleep(nanoseconds: 200_000_000) // simulate heavy work
            return 123
        }
        
        await withTaskGroup(of: Int.self) { group in
            for _ in 1...concurrentCalls {
                group.addTask {
                    await lazy.value
                }
            }
            
            for await val in group {
                #expect(val == 123, "All concurrent fetches return the same value.")
            }
        }
        
        #expect(await counter.value() == 1, "Factory must be called exactly once.")
    }
    
    /// Tests concurrency + transformations (`map`), ensuring only one base init and correct mapped values.
    @Test
    func testConcurrentMapAccess() async {
        let baseLazy = AsyncLazy {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return 10
        }
        
        let mapped1 = await baseLazy.map({ $0 * 2 }, initializationTask: nil)       // => 20
        let mapped2 = await baseLazy.map({ $0 + 5 }, initializationTask: nil)       // => 15
        let mapped3 = await baseLazy.map({ $0 * $0 }, initializationTask: nil)      // => 100
        
        await withTaskGroup(of: [Int].self) { group in
            for _ in 1...3 {
                group.addTask {
                    let v1 = await mapped1.value
                    let v2 = await mapped2.value
                    let v3 = await mapped3.value
                    return [v1, v2, v3]
                }
            }
            
            for await results in group {
                #expect(results == [20, 15, 100], "Mapped values should be [20, 15, 100].")
            }
        }
    }
    
    // MARK: - Stress / Performance Tests
    
    /// Stress test with repeated concurrent fetches to ensure stable performance.
    @Test
    func testHighLoadStress() async {
        let concurrencyLevel = 100
        let repeatCount = 3
        let counter = Counter()
        
        let lazy = AsyncLazy {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 500_000_000) // simulate heavier work
            return 999
        }
        
        for _ in 1...repeatCount {
            await withTaskGroup(of: Int.self) { group in
                for _ in 1...concurrencyLevel {
                    group.addTask {
                        await lazy.value
                    }
                }
                for await val in group {
                    #expect(val == 999, "All repeated calls must see the same value.")
                }
            }
        }
        
        #expect(await counter.value() == 1, "Even under heavy repeated load, the factory should only be called once.")
    }
    
    /// Stress test with a combination of `value`, `map`, and `uponInitiation` calls, in parallel.
    @Test
    func testComplexConcurrentStress() async {
        let baseLazy = AsyncLazy {
            let randomVal = Int.random(in: 1...1000)
            try? await Task.sleep(nanoseconds: 200_000_000)
            return randomVal
        }
        
        // Register multiple post-initialization tasks
        for i in 1...5 {
            await baseLazy.uponInitiation(task: .init(work: { val in
                print("Initiation Task \(i) got value: \(val)")
            }, priority: nil))
        }
        
        let concurrencyLevel = 50
        
        await withTaskGroup(of: Void.self) { group in
            // 1) Some tasks call `value`
            for _ in 1...(concurrencyLevel / 2) {
                group.addTask {
                    _ = await baseLazy.value
                }
            }
            
            // 2) Some tasks do a `map` call
            for _ in 1...(concurrencyLevel / 2) {
                group.addTask {
                    let mapped = await baseLazy.map({ $0 * 2 }, initializationTask: nil)
                    _ = await mapped.value
                }
            }
        }
        
        #expect(await baseLazy.isInitiated, "Value should be initiated after heavy concurrency.")
    }
}

/// A small actor to help tests wait for an async signal.
actor AsyncWaiter {
    private var continuation: CheckedContinuation<Void, Never>?
    private var signaled = false
    
    func wait() async {
        if signaled { return }
        await withCheckedContinuation { self.continuation = $0 }
    }
    
    func signal() {
        signaled = true
        continuation?.resume()
        continuation = nil
    }
}
