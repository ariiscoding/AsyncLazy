# AsyncLazy

`AsyncLazy` is a lightweight Swift concurrency utility for lazily initializing and caching values in a thread-safe manner. It only computes the value upon first request, and all subsequent requests await that same result. This design eliminates redundant calculations and simplifies concurrent workflows.

---

## Features

- **Actor-based** – Ensures thread safety without manual locks or complicated synchronization.  
- **Single Initialization** – Guarantees only one invocation of the factory closure, even under heavy concurrency.  
- **Flexible** – Optional convenience APIs like `map` and `uponInitiation` let you transform or observe values after creation.  
- **Performance-Focused** – Minimal overhead; only lock-free concurrency operations via Swift actors.

---

## Requirements

- Swift 6.0 or later. 
- Works on iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+, visionOS 1+ (or matching Swift concurrency back-deployment targets).

---

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/arihe/AsyncLazy.git", from: "1.0.0")
]
```

Then add `AsyncLazy` as a dependency in your target:

```swift
.target(name: "YourAppOrLibrary", dependencies: [
    .product(name: "AsyncLazy", package: "AsyncLazy")
])
```

---

## Usage

1. **Create an `AsyncLazy`** with a factory closure that provides the value:

   ```swift
   let lazyValue = AsyncLazy {
       // Simulate a slow operation
       try? await Task.sleep(nanoseconds: 300_000_000)
       return "Hello, AsyncLazy!"
   }
   ```

2. **Retrieve the value** – The first time you call `.value`, it triggers the factory. All subsequent calls wait on that same result:

   ```swift
   Task {
       let val = await lazyValue.value
       print(val) // Prints: Hello, AsyncLazy!
   }
   ```

3. **Check if initiated** – `isInitiated` tells you if the value has already been created:

   ```swift
   if await lazyValue.isInitiated {
       print("Value was already created.")
   } else {
       print("Still uninitiated.")
   }
   ```

4. **Perform tasks upon initialization** – Want to run some async work once the value is ready? Use `uponInitiation`:

   ```swift
   lazyValue.uponInitiation(task: .init(work: { val in
       print("Value is now ready: \(val)")
   }, priority: nil))
   ```

5. **Transform with `map`** – Create a new `AsyncLazy` derived from the original:

   ```swift
   let mapped = await lazyValue.map { str in
       "Mapped: \(str.uppercased())"
   } initializationTask: nil
   
   let mappedVal = await mapped.value
   // => "Mapped: HELLO, ASYNCLAZY!"
   ```

---

## Testing

This package includes a robust suite of Swift tests (using `XCTest` or SwiftTest) covering:

- Basic initialization and access  
- Concurrency scenarios  
- Stress tests under high load  
- Verification of single-invocation guarantees  

Simply open the project in Xcode and run the tests (⌘U), or from the command line:

```bash
swift test
```

---

## License

This project is released under the [MIT License](LICENSE).  
© 2025 Ari He. All rights reserved.

---

## Contributing

Contributions are welcome! If you find a bug or have a feature request:

1. Open an [issue](https://github.com/arihe/AsyncLazy/issues).  
2. Or fork, make changes, and submit a pull request.
