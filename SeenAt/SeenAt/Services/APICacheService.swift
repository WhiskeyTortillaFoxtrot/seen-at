import Foundation

enum APICacheService {
    static let session: URLSession = {
        let cache = URLCache(memoryCapacity: 5_000_000, diskCapacity: 20_000_000, diskPath: "api-cache")
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        return URLSession(configuration: config)
    }()
}
