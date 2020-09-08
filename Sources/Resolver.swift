// Ok, so we're gonna take ownership of this file...
// Changelog:
//  LOA-793 (~8/1/20, sara):
//   Added Resolver to Common
//   Adjusted conditional import statements - avoid swiftUI import & related code unless swiftUI available
//   Created ServiceIdentifier to replace bare strings for naming
//   Replaced NONAME -> ServiceIdentifier.none
//   Created ResolverFactoryArgumentsIdentifier - we can now pass the ServiceIdentifier
//      associated with the current service resolution to the resolved factory function
//   Also created ResolverFactoryMutatorArgumentsIdentifier, same thing but for the mutating factory function type
//   Set ServiceIdentifier.none for default parameter and made ServiceIdentifier params non-optional
//      (no functionality change - providing a nil name used to map to NONAME anyway)
//   Set default scoping to application (was graph) - this is most convenient for our purposes rn
//      Anything with persistent state throughout the app lifetime absolutely _must_ be application- or cache-scoped
//      Some other things should be app-scoped as well,
//          e.g. HostProviders, which are currently resolved by 
//      We should test what works best, performance-wise.
//
//   Swiftlint/code cleanup pass
//
//  [your stuff here]

//  TODO: at some point...
//  - This file is getting big; we can move some things (e.g. property wrappers) elsewhere
//  - allow resolution by name even when something wasn't registered by name
//  -- if a name is provided but doesn't match anything on the resolved type,
//  --  check if we have a ResolverFactory[Mutator]ArgumentsIdentifier for that type with no name.
//  --  if so, invoke that factory, using the name that the user wants to resolve, rather than no name.

// Resolver.swift
//
// GitHub Repo and Documentation: https://github.com/hmlongco/Resolver
// swiftlint:disable:next template_header
// Copyright © 2017 Michael Long. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if os(iOS)
import UIKit
#else
import Foundation
#endif

public struct ServiceIdentifier: Hashable, Equatable {
    fileprivate let name: String

    public init(name: String) {
        self.name = name
    }

    public static let none = Self(name: "*")
}

public protocol ResolverRegistering {
    static func registerAllServices()
}

/// The Resolving protocol is used to make the Resolver registries available to a given class.
public protocol Resolving {
    var resolver: Resolver { get }
}

extension Resolving {
    public var resolver: Resolver {
        return Resolver.root
    }
}

/// Resolver is a Dependency Injection registry that registers Services for later resolution and
/// injection into newly constructed instances.
public final class Resolver {
    // MARK: - Defaults
    /// Default registry used by the static Registration functions.
    public static var main: Resolver = Resolver()
    /// Default registry used by the static Resolution functions and by the Resolving protocol.
    public static var root: Resolver = main
    /// Default scope applied when registering new objects.
    /// Changing default to application scope 'cuz most of our services are gonna be long-lived
    public static var defaultScope: ResolverScope = Resolver.application

    // MARK: - Lifecycle
    public init(parent: Resolver? = nil) {
        self.parent = parent
    }

    /// Called by the Resolution functions to perform one-time initialization of the Resolver registries.
    public final func registerServices() {
        Resolver.registerServices?()
    }

    /// Called by the Resolution functions to perform one-time initialization of the Resolver registries.
    public static var registerServices: (() -> Void)? = registerServicesBlock

    private static var registerServicesBlock: (() -> Void) = { () in
        pthread_mutex_lock(&Resolver.registrationMutex)
        defer { pthread_mutex_unlock(&Resolver.registrationMutex) }
        if Resolver.registerServices != nil, let registering = (Resolver.root as Any) as? ResolverRegistering {
            type(of: registering).registerAllServices()
        }
        Resolver.registerServices = nil
    }

    /// Called to effectively reset Resolver to its initial state,
    ///  including recalling registerAllServices if it was provided
    public static func reset() {
        pthread_mutex_lock(&Resolver.registrationMutex)
        defer { pthread_mutex_unlock(&Resolver.registrationMutex) }
        main = Resolver()
        root = main
        registerServices = registerServicesBlock
    }

    // MARK: - Service Registration
    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(_ type: Service.Type = Service.self, name: ServiceIdentifier = .none,
                                         factory: @escaping ResolverFactory<Service>) -> ResolverOptions<Service> {
        return main.register(type, name: name, factory: { (_, _, _) -> Service? in return factory() })
    }

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryResolver<Service>
    ) -> ResolverOptions<Service> {
        return main.register(type, name: name, factory: { (r, _, _) -> Service? in return factory(r) })
    }

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryArguments<Service>
    ) -> ResolverOptions<Service> {
        return main.register(type, name: name, factory: { (r, args, _) -> Service? in return factory(r, args) })
    }

    /// Static shortcut function used to register a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public static func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryArgumentsIdentifier<Service>
    ) -> ResolverOptions<Service> {
        return main.register(type, name: name, factory: factory)
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactory<Service>
    ) -> ResolverOptions<Service> {
        return register(type, name: name, factory: { (_, _, _) -> Service? in return factory() })
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryResolver<Service>
    ) -> ResolverOptions<Service> {
        return register(type, name: name, factory: { (r, _, _) -> Service? in return factory(r) })
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryArguments<Service>
    ) -> ResolverOptions<Service> {
        return register(type, name: name, factory: { (r, args, _) -> Service? in return factory(r, args) })
    }

    /// Registers a specific Service type and its instantiating factory method.
    ///
    /// - parameter type: Type of Service being registered. Optional, may be inferred by factory result type.
    /// - parameter name: Named variant of Service being registered.
    /// - parameter factory: Closure that accepts arguments and the service identifier
    ///     and constructs and returns instances of the Service.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func register<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        factory: @escaping ResolverFactoryArgumentsIdentifier<Service>
    ) -> ResolverOptions<Service> {
        let key = ObjectIdentifier(Service.self).hashValue
        let registration = ResolverRegistration(resolver: self, key: key, name: name, factory: factory)
        if var container = registrations[key] {
            container[name] = registration
            registrations[key] = container
        } else {
            registrations[key] = [name: registration]
        }
        return registration
    }

    // MARK: - Service Resolution
    /// Static function calls the root registry to resolve a given Service type.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    public static func resolve<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        args: Any? = nil
    ) -> Service {
        Resolver.registerServices?() // always check initial registrations first in case registerAllServices swaps root
        return root.resolve(type, name: name, args: args)
    }

    /// Resolves and returns an instance of the given Service type from the current registry or from its
    /// parent registries.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public final func resolve<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        args: Any? = nil
    ) -> Service {
        if
            let registration = lookup(type, name: name),
            let service = registration.scope.resolve(resolver: self, registration: registration, args: args, name: name)
        {
            return service
        }
        fatalError("RESOLVER: '\(Service.self):\(name.name)' not resolved. For optionals use resover.optional().")
    }

    /// Static function calls the root registry to resolve an optional Service type.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public static func optional<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        args: Any? = nil
    ) -> Service? {
        Resolver.registerServices?() // always check initial registrations first in case registerAllServices swaps root
        return root.optional(type, name: name, args: args)
    }

    /// Resolves and returns an optional instance of the given Service type from the current registry or
    /// from its parent registries.
    ///
    /// - parameter type: Type of Service being resolved. Optional, may be inferred by assignment result type.
    /// - parameter name: Named variant of Service being resolved.
    /// - parameter args: Optional arguments that may be passed to registration factory.
    ///
    /// - returns: Instance of specified Service.
    ///
    public final func optional<Service>(
        _ type: Service.Type = Service.self,
        name: ServiceIdentifier = .none,
        args: Any? = nil
    ) -> Service? {
        if
            let registration = lookup(type, name: name),
            let service = registration.scope.resolve(resolver: self, registration: registration, args: args, name: name)
        {
            return service
        }
        return nil
    }

    // MARK: - Internal
    /// Internal function searches the current and parent registries for a ResolverRegistration<Service> that matches
    /// the supplied type and name.
    private final func lookup<Service>(
        _ type: Service.Type,
        name: ServiceIdentifier
    ) -> ResolverRegistration<Service>? {
        Resolver.registerServices?()
        if let container = registrations[ObjectIdentifier(Service.self).hashValue] {
            return container[name] as? ResolverRegistration<Service>
        }
        if let parent = parent, let registration = parent.lookup(type, name: name) {
            return registration
        }
        return nil
    }

    private let parent: Resolver?
    private var registrations = [Int: [ServiceIdentifier: Any]]()
    private static var registrationMutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()
}

// Registration Internals
public typealias ResolverFactory<Service> = () -> Service?

public typealias ResolverFactoryResolver<Service> = (_ resolver: Resolver) -> Service?

public typealias ResolverFactoryArguments<Service> = (_ resolver: Resolver, _ args: Any?) -> Service?

public typealias ResolverFactoryArgumentsIdentifier<Service> = (
        _ resolver: Resolver,
        _ args: Any?,
        _ name: ServiceIdentifier
    ) -> Service?

public typealias ResolverFactoryMutator<Service> = (_ resolver: Resolver, _ service: Service) -> Void

public typealias ResolverFactoryMutatorArguments<Service> = (
        _ resolver: Resolver,
        _ service: Service,
        _ args: Any?
    ) -> Void

// "Identifier" used to be "Named" ("Name" would work too)
//   both would bring us under 40chars
// swiftlint:disable:next type_name
public typealias ResolverFactoryMutatorArgumentsIdentifier<Service> = (
        _ resolver: Resolver,
        _ service: Service,
        _ args: Any?,
        _ name: ServiceIdentifier
    ) -> Void

/// A ResolverOptions instance is returned by a registration function
///  in order to allow additonal configuration. (e.g. scopes, etc.)
public class ResolverOptions<Service> {
    // MARK: - Parameters
    public var scope: ResolverScope

    fileprivate var factory: ResolverFactoryArgumentsIdentifier<Service>
    fileprivate var mutator: ResolverFactoryMutatorArgumentsIdentifier<Service>?
    fileprivate weak var resolver: Resolver?

    // MARK: - Lifecycle
    public init(
        resolver: Resolver,
        factory: @escaping ResolverFactoryArgumentsIdentifier<Service>
    ) {
        self.factory = factory
        self.resolver = resolver
        self.scope = Resolver.defaultScope
    }

    // MARK: - Fuctionality
    /// Indicates that the registered Service also implements a specific protocol that may be resolved on
    /// its own.
    ///
    /// - parameter type: Type of protocol being registered.
    /// - parameter name: Named variant of protocol being registered.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func implements<Protocol>(
        _ type: Protocol.Type,
        name: ServiceIdentifier = .none
    ) -> ResolverOptions<Service> {
        resolver?.register(type.self, name: name) { r, _ in r.resolve(Service.self) as? Protocol }
        return self
    }

    /// Allows easy assignment of injected properties into resolved Service.
    ///
    /// - parameter block: Resolution block.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func resolveProperties(
        _ block: @escaping ResolverFactoryMutator<Service>
    ) -> ResolverOptions<Service> {
        mutator = { (r, s, _, _) in block(r, s) }
        return self
    }

    /// Allows easy assignment of injected properties into resolved Service.
    ///
    /// - parameter block: Resolution block that also receives resolution arguments.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func resolveProperties(
        _ block: @escaping ResolverFactoryMutatorArguments<Service>
    ) -> ResolverOptions<Service> {
        mutator = { (r, s, args, _) in block(r, s, args) }
        return self
    }

    /// Allows easy assignment of injected properties into resolved Service.
    ///
    /// - parameter block: Resolution block that also receives resolution arguments and service id.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func resolveProperties(
        _ block: @escaping ResolverFactoryMutatorArgumentsIdentifier<Service>
    ) -> ResolverOptions<Service> {
        mutator = block
        return self
    }

    //resolveprops mutator/args/id here

    /// Defines scope in which requested Service may be cached.
    ///
    /// - parameter block: Resolution block.
    ///
    /// - returns: ResolverOptions instance that allows further customization of registered Service.
    ///
    @discardableResult
    public final func scope(_ scope: ResolverScope) -> ResolverOptions<Service> {
        self.scope = scope
        return self
    }
}

/// ResolverRegistration stores a service definition and its factory closure.
public final class ResolverRegistration<Service>: ResolverOptions<Service> {
    // MARK: Parameters
    public var key: Int
    public var cacheKey: String

    // MARK: Lifecycle
    public init(
        resolver: Resolver,
        key: Int,
        name: ServiceIdentifier?,
        factory: @escaping ResolverFactoryArgumentsIdentifier<Service>
    ) {
        self.key = key
        if let namedService = name {
            self.cacheKey = String(key) + ":" + namedService.name
        } else {
            self.cacheKey = String(key)
        }
        super.init(resolver: resolver, factory: factory)
    }

    // MARK: Functions
    public final func resolve(
        resolver: Resolver,
        args: Any?,
        name: ServiceIdentifier
    ) -> Service? {
        guard let service = factory(resolver, args, name) else {
            return nil
        }
        self.mutator?(resolver, service, args, name)
        return service
    }
}

// Scopes
extension Resolver {
    /// All application scoped services exist for lifetime of the app. (e.g Singletons)
    public static let application = ResolverScopeApplication()
    /// Cached services exist for lifetime of the app or until their cache is reset.
    public static let cached = ResolverScopeCache()
    /// Graph services are initialized once and only once during a given resolution cycle. This is the default scope.
    public static let graph = ResolverScopeGraph()
    /// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
    public static let shared = ResolverScopeShare()
    /// Unique services are created and initialized each and every time they're resolved.
    public static let unique = ResolverScopeUnique()

}

/// Resolver scopes exist to control when resolution occurs and how resolved instances are cached. (If at all.)
public protocol ResolverScope: class {
    func resolve<Service>(
        resolver: Resolver,
        registration: ResolverRegistration<Service>,
        args: Any?,
        name: ServiceIdentifier
    ) -> Service?
}

/// All application scoped services exist for lifetime of the app. (e.g Singletons)
/// This is (now) the default scope.
public class ResolverScopeApplication: ResolverScope {
    public init() {
        pthread_mutex_init(&mutex, nil)
    }

    public final func resolve<Service>(
        resolver: Resolver,
        registration: ResolverRegistration<Service>,
        args: Any?,
        name: ServiceIdentifier = .none
    ) -> Service? {
        pthread_mutex_lock(&mutex)
        let existingService = cachedServices[registration.cacheKey] as? Service
        pthread_mutex_unlock(&mutex)

        if let service = existingService {
            return service
        }

        let service = registration.resolve(resolver: resolver, args: args, name: name)

        if let service = service {
            pthread_mutex_lock(&mutex)
            cachedServices[registration.cacheKey] = service
            pthread_mutex_unlock(&mutex)
        }

        return service
    }

    fileprivate var cachedServices = [String: Any](minimumCapacity: 32)
    fileprivate var mutex = pthread_mutex_t()
}

/// Cached services exist for lifetime of the app or until their cache is reset.
public final class ResolverScopeCache: ResolverScopeApplication {
    override public init() {
        super.init()
    }

    public final func reset() {
        pthread_mutex_lock(&mutex)
        cachedServices.removeAll()
        pthread_mutex_unlock(&mutex)
    }
}

/// Graph services are initialized once and only once during a given resolution cycle.
public final class ResolverScopeGraph: ResolverScope {
    public init() {
        pthread_mutex_init(&mutex, nil)
    }

    public final func resolve<Service>(
        resolver: Resolver,
        registration: ResolverRegistration<Service>,
        args: Any?,
        name: ServiceIdentifier = .none
    ) -> Service? {
        pthread_mutex_lock(&mutex)
        let existingService = graph[registration.cacheKey] as? Service

        if let service = existingService {
            pthread_mutex_unlock(&mutex)
            return service
        }

        resolutionDepth += 1
        pthread_mutex_unlock(&mutex)

        let service = registration.resolve(resolver: resolver, args: args, name: name)

        pthread_mutex_lock(&mutex)
        resolutionDepth -= 1

        if resolutionDepth == 0 {
            graph.removeAll()
        } else if let service = service, type(of: service as Any) is AnyClass {
            graph[registration.cacheKey] = service
        }
        pthread_mutex_unlock(&mutex)

        return service
    }

    private var graph = [String: Any?](minimumCapacity: 32)
    private var resolutionDepth: Int = 0
    private var mutex = pthread_mutex_t()
}

/// Shared services persist while strong references to them exist. They're then deallocated until the next resolve.
public final class ResolverScopeShare: ResolverScope {
    public init() {
        pthread_mutex_init(&mutex, nil)
    }

    public final func resolve<Service>(
        resolver: Resolver,
        registration: ResolverRegistration<Service>,
        args: Any?,
        name: ServiceIdentifier = .none
    ) -> Service? {
        pthread_mutex_lock(&mutex)
        let existingService = cachedServices[registration.cacheKey]?.service as? Service
        pthread_mutex_unlock(&mutex)

        if let service = existingService {
            return service
        }

        let service = registration.resolve(resolver: resolver, args: args, name: name)

        if let service = service, type(of: service as Any) is AnyClass {
            pthread_mutex_lock(&mutex)
            cachedServices[registration.cacheKey] = BoxWeak(service: service as AnyObject)
            pthread_mutex_unlock(&mutex)
        }

        return service
    }

    public final func reset() {
        pthread_mutex_lock(&mutex)
        cachedServices.removeAll()
        pthread_mutex_unlock(&mutex)
    }

    private struct BoxWeak {
        weak var service: AnyObject?
    }

    private var cachedServices = [String: BoxWeak](minimumCapacity: 32)
    private var mutex = pthread_mutex_t()
}

/// Unique services are created and initialized each and every time they're resolved.
public final class ResolverScopeUnique: ResolverScope {
    public init() { }
    public final func resolve<Service>(
        resolver: Resolver,
        registration: ResolverRegistration<Service>,
        args: Any?,
        name: ServiceIdentifier = .none
    ) -> Service? {
        return registration.resolve(resolver: resolver, args: args, name: name)
    }

}

#if os(iOS)
/// Storyboard Automatic Resolution Protocol
public protocol StoryboardResolving: Resolving {
    func resolveViewController()
}

/// Storyboard Automatic Resolution Trigger
public extension UIViewController {
    // swiftlint:disable unused_setter_value
    @objc dynamic var resolving: Bool {
        get {
            return true
        }
        set {
            if let vc = self as? StoryboardResolving {
                vc.resolveViewController()
            }
        }
    }
    // swiftlint:enable unused_setter_value
}
#endif

// Swift Property Wrappers

#if swift(>=5.1)
/// Immediate injection property wrapper.
///
/// Wrapped dependent service is resolved immediately using Resolver.root upon struct initialization.
///
@propertyWrapper
public struct Injected<Service> {
    private var service: Service
    public init(name: ServiceIdentifier = .none, container: Resolver? = nil) {
        self.service = container?.resolve(Service.self, name: name) ?? Resolver.resolve(Service.self, name: name)
    }
    public var wrappedValue: Service {
        get { return service }
        mutating set { service = newValue }
    }
    public var projectedValue: Injected<Service> {
        get { return self }
        mutating set { self = newValue }
    }
}

/// Lazy injection property wrapper.
/// Note that embedded container and name properties will be used if set prior to service instantiation.
///
/// Wrapped dependent service is not resolved until service is accessed.
///
@propertyWrapper
public struct LazyInjected<Service> {
    private var service: Service!
    public var container: Resolver?
    public var name: ServiceIdentifier
    public init(name: ServiceIdentifier = .none, container: Resolver? = nil) {
        self.name = name
        self.container = container
    }
    public var isEmpty: Bool {
        return service == nil
    }
    public var wrappedValue: Service {
        mutating get {
            if self.service == nil {
                if let container = container {
                    self.service = container.resolve(Service.self, name: name)
                } else {
                    self.service = Resolver.resolve(Service.self, name: name)
                }
            }
            return service
        }
        mutating set { service = newValue }
    }
    public var projectedValue: LazyInjected<Service> {
        get { return self }
        mutating set { self = newValue }
    }
    public mutating func release() {
        self.service = nil
    }
}

@propertyWrapper
public struct OptionalInjected<Service> {
    private var service: Service?
    public init() {
        self.service = Resolver.optional(Service.self)
    }
    public init(name: ServiceIdentifier = .none, container: Resolver? = nil) {
        self.service = container?.optional(Service.self, name: name) ?? Resolver.optional(Service.self, name: name)
    }
    public var wrappedValue: Service? {
        get { return service }
        mutating set { service = newValue }
    }
    public var projectedValue: OptionalInjected<Service> {
        get { return self }
        mutating set { self = newValue }
    }
}

#if canImport(SwiftUI)
import SwiftUI
/// Immediate injection property wrapper for SwiftUI ObservableObjects.
/// This wrapper is meant for use in SwiftUI Views and exposes bindable objects
/// similar to that of SwiftUI @observedObject and @environmentObject.
///
/// Dependent service must be of type ObservableObject. Updating object state will trigger view update.
///
/// Wrapped dependent service is resolved immediately using Resolver.root upon struct initialization.
///
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@propertyWrapper
public struct InjectedObject<Service>: DynamicProperty where Service: ObservableObject {
    @ObservedObject private var service: Service
    public init() {
        self.service = Resolver.resolve(Service.self)
    }
    public init(name: ServiceIdentifier = .none, container: Resolver? = nil) {
        self.service = container?.resolve(Service.self, name: name) ?? Resolver.resolve(Service.self, name: name)
    }
    public var wrappedValue: Service {
        get { return service }
        mutating set { service = newValue }
    }
    public var projectedValue: ObservedObject<Service>.Wrapper {
        return self.$service
    }
}

#endif
#endif
//swiftlint:disable:this file_length
