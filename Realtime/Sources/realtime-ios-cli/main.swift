import Foundation
import Realtime

// Run the tests
Task {
    do {
        let tests = try RealtimeTests(
            apiKey:
                "eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJhdWQiOiJOQVRTIiwibmFtZSI6IklPUyBEZXYiLCJzdWIiOiJVRFdYRDQ0Q01OSlpGU1NCTlNYU1ZNUUJFVE9JNlpQTkU3VkxGUEhKNk5DVE9WNTNTTkhJV0FaSiIsIm5hdHMiOnsiZGF0YSI6LTEsInBheWxvYWQiOi0xLCJzdWJzIjotMSwicHViIjp7ImRlbnkiOlsiPiJdfSwic3ViIjp7ImRlbnkiOlsiPiJdfSwib3JnX2RhdGEiOnsib3JnYW5pemF0aW9uIjoicmVsYXktaW50ZXJuYWwiLCJwcm9qZWN0IjoiSU9TIERldiJ9LCJpc3N1ZXJfYWNjb3VudCI6IkFDWklKWkNJWFNTVVU1NVlFR01QMjM2TUpJMkNSSVJGRkdJRDRKVlE2V1FZWlVXS08yVTdZNEJCIiwidHlwZSI6InVzZXIiLCJ2ZXJzaW9uIjoyfSwiaXNzIjoiQUNaSUpaQ0lYU1NVVTU1WUVHTVAyMzZNSkkyQ1JJUkZGR0lENEpWUTZXUVlaVVdLTzJVN1k0QkIiLCJpYXQiOjE3NDM1MDMzNDUsImp0aSI6Ilo5SExZMi8xdnh1Q0psb1M5RnNjRkRobTN3Ym05SmgrRy9NTnBRQ21BTHBoODVFSmJMV0VBaGJvTkl6ZHZkZ0ZTd1QzcjRMU1M5RW56QkNpWWxpWTNnPT0ifQ.k2yssWr8KHbTMztg7QZpfbjJL1ZnLvX79KkSKnn5COaqUKvr0Hh6NNbLW8dwK6PG19FxhTXbGLSzMinSBcAkDA",
            secret: "SUABDOOLKL6MUTUMSXHRQFCNAHRYABWGVY7FE7XU5T5RDKC4JWCVOMSJO4"
        )
        try await tests.runAllTests()
    } catch {
        print("\n❌ Error running tests:")
        print("   Error type: \(type(of: error))")
        print("   Description: \(error)")
        print("   Localized: \(error.localizedDescription)")
        if let relayError = error as? RelayError {
            print("   RelayError: \(relayError)")
        }
    }
    exit(0)
}

// Keep the main thread running
RunLoop.main.run()
