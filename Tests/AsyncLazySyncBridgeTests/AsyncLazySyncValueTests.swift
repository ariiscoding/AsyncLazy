
import Testing
import Foundation
@testable import AsyncLazy
@testable import AsyncLazySyncBridge
import TestUtils

struct AsyncLazySyncValueTests {
    
    @Test
    func testSynchronousValueBasic() async {
        let counter = Counter()
        
        let lazy = AsyncLazy {
            await counter.increment()
            // Simulate async work
            try? await Task.sleep(nanoseconds: 50_000_000)
            return "Hello, Sync!"
        }
        
        // Call synchronousValue once
        let result = lazy.synchronousValue()
        #expect(result == "Hello, Sync!", "Should return the string from the factory.")
        #expect(await counter.value() == 1, "Factory should be called exactly once on first sync call.")
        
        // Call again
        let secondResult = lazy.synchronousValue()
        #expect(secondResult == "Hello, Sync!")
        #expect(await counter.value() == 1, "Second sync call should not call the factory again.")
    }
    
    @Test
    func testSynchronousValueMultipleCalls() async {
        let counter = Counter()
        
        let lazy = AsyncLazy {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 100_000_000)
            return Int.random(in: 0..<1000)
        }
        
        let val1 = lazy.synchronousValue()
        let val2 = lazy.synchronousValue()
        let val3 = lazy.synchronousValue()
        
        #expect(val1 == val2 && val2 == val3, "All sync calls must return the same value.")
        #expect(await counter.value() == 1, "Repeated sync calls should not cause multiple initializations.")
    }
    
    @Test
    func testSynchronousValueConcurrent() async {
        let concurrencyLevel = 10
        
        let counter = Counter()
        let lazy = AsyncLazy {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 200_000_000)
            return 42
        }
        
        // We'll gather the results in a local array
        var results = [Int]()
        results.reserveCapacity(concurrencyLevel)
        
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<concurrencyLevel {
                group.addTask {
                    // Each parallel Task calls synchronousValue
                    return lazy.synchronousValue()
                }
            }
            
            // Collect each Task’s return
            for await val in group {
                results.append(val)
            }
        }
        
        // Check if all results are the same
        let firstValue = results.first ?? -1
        let allSame = results.allSatisfy { $0 == firstValue }
        
        #expect(allSame, "All tasks should retrieve the same value (42).")
        #expect(await counter.value() == 1, "Factory must only be called once, even under concurrency.")
    }
    
    @Test
    func testSynchronousValueWithAlreadyInitialized() async {
        let counter = Counter()
        
        let lazy = AsyncLazy {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 100_000_000)
            return "AsyncThenSync"
        }
        
        // Initialize via async
        let asyncValue = await lazy.value
        #expect(asyncValue == "AsyncThenSync")
        #expect(await counter.value() == 1)
        
        // Then call synchronousValue
        let syncValue = lazy.synchronousValue()
        #expect(syncValue == "AsyncThenSync", "Sync call should return pre-initialized value.")
        #expect(await counter.value() == 1, "No additional factory call after async init.")
    }
}
