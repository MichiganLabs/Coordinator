import Foundation

// Reasons for not making a Type-Safe ServiceLocator class:
// * Some modules may need to add their own service to this class and this module is not required by any other module

public protocol ServiceLocating {
    func get<T>() throws -> T
}

public enum ServiceLocatingError: Error {
    case noServiceFound(String)
}

// ServiceLocator should not be a dependency beyond the coordinator level. All view controllers and models should
// have their individual dependencies injected.
public final class ServiceLocator: ServiceLocating {
    public init() {}

    private lazy var services: [String: Any] = [:]
    private func typeName(some: Any) -> String {
        return (some is Any.Type) ? "\(some)" : "\(type(of: some))"
    }

    public func add<T>(service: T) {
        let key = typeName(some: T.self)
        services[key] = service
    }

    public func get<T>() throws -> T {
        let key = typeName(some: T.self)
        if let service = services[key] as? T {
            return service
        } else {
            throw ServiceLocatingError.noServiceFound(key)
        }
    }
}
