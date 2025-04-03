import Foundation

public enum NatsConstants {
    public enum JetStream {
        public static let apiPrefix = "$JS.API"
        
        public static let accountInfo = "\(apiPrefix).ACCOUNT.INFO"
        
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
            
            public static func create(stream: String) -> String {
                "\(apiPrefix).STREAM.CREATE.\(stream)"
            }
        }
        
        public enum Consumer {
            public static func create(stream: String) -> String {
                "\(apiPrefix).CONSUMER.CREATE.\(stream)"
            }
            
            public static func next(stream: String, consumer: String) -> String {
                "\(apiPrefix).CONSUMER.MSG.NEXT.\(stream).\(consumer)"
            }
        }
    }
} 