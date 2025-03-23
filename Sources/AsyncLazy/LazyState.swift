
import Foundation

enum LazyState<ValueType> {
    case toBeCreated(factory: (() async throws -> ValueType))
    case created(value: ValueType)
}
