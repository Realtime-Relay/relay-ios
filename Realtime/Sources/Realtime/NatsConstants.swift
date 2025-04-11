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
        }
    }

    public enum Topics {
        public static func formatTopic(_ topic: String, namespace: String) -> String {
            // Format: namespace_stream_topic
            // Use components(separatedBy:) and joined(separator:) for more efficient string manipulation
            let formattedTopic = topic.components(separatedBy: ".").joined(separator: "_")
            return [namespace, "stream", formattedTopic].joined(separator: "_")
        }
    }
}
