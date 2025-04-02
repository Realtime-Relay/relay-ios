import Foundation

public enum NatsConstants {
    public enum JetStream {
        public static let apiPrefix = "$JS.API"
        
        public enum Stream {
            public static func info(stream: String) -> String {
                "\(apiPrefix).STREAM.INFO.\(stream)"
            }
            
            public static func message(stream: String) -> String {
                "\(apiPrefix).STREAM.MSG.GET.\(stream)"
            }
        }
    }
} 