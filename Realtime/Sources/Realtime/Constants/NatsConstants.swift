import Foundation

public enum NatsConstants {
    public enum JetStream {
        public static let apiPrefix = "$JS.API"
        
        public enum Stream {
            public static func info(stream: String) -> String {
                "\(apiPrefix).STREAM.INFO.\(stream)"
            }
            
            public static func message(stream: String) -> String {
                "\(apiPrefix).STREAM.DIRECT.GET.\(stream)"
            }
            
            public static func consumer(stream: String) -> String {
                "\(apiPrefix).CONSUMER.CREATE.\(stream)"
            }
            
            public static func consumerNext(stream: String, consumer: String) -> String {
                "\(apiPrefix).CONSUMER.MSG.NEXT.\(stream).\(consumer)"
            }
            
            public static func consumerDelete(stream: String, consumer: String) -> String {
                "\(apiPrefix).CONSUMER.DELETE.\(stream).\(consumer)"
            }
        }
    }
    
    public enum Topics {
        public static func formatTopic(_ topic: String) -> String {
            return "\(namespace)_stream_\(topic)"
        }
        
        public static let namespace: String = "relay"
    }
} 