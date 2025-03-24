
import Foundation

// MARK: - A small actor for concurrency-safe counting
public actor Counter {
    private var _count = 0
    
    func increment() {
        _count += 1
    }
    
    func value() -> Int {
        _count
    }
}
