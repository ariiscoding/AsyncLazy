
import Foundation

/// A small actor for concurrency-safe counting.
public actor Counter {
    private var _count = 0
    
    public init() {}
    
    public func increment() {
        _count += 1
    }
    
    public func value() -> Int {
        _count
    }
}
