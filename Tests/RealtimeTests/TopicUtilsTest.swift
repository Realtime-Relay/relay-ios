import XCTest
@testable import Realtime

final class TopicPatternMatcherTests: XCTestCase {

    /// (pattern, topic, expectedResult)
    private let cases: [(String, String, Bool)] = [
        ("foo",                 "foo",                      true),   // 1
        ("foo",                 "bar",                      false),  // 2
        ("foo.*",               "foo.bar",                  true),   // 3
        ("foo.bar",             "foo.*",                    true),   // 4
        ("*",                   "token",                    true),   // 5
        ("*",                   "*",                        true),   // 6
        ("foo.*",               "foo.bar.baz",              false),  // 7
        ("foo.>",               "foo.bar.baz",              true),   // 8
        ("foo.>",               "foo",                      false),  // 9
        ("foo.bar.baz",         "foo.>",                    true),   // 10
        ("foo.bar.>",           "foo.bar",                  false),  // 11
        ("foo",                 "foo.>",                    false),  // 12
        ("foo.*.>",             "foo.bar.baz.qux",          true),   // 13
        ("foo.*.baz",           "foo.bar.>",                true),   // 14
        ("alpha.*",             "beta.gamma",               false),  // 15
        ("alpha.beta",          "alpha.*.*",                false),  // 16
        ("foo.>.bar",           "foo.any.bar",              false),  // 17
        (">",                   "foo.bar",                  true),   // 18
        (">",                   ">",                        true),   // 19
        ("*",                   ">",                        true),   // 20
        ("*.>",                 "foo.bar",                  true),   // 21
        ("*.*.*",               "a.b.c",                    true),   // 22
        ("*.*.*",               "a.b",                      false),  // 23
        ("a.b.c.d.e",           "a.b.c.d.e",                true),   // 24
        ("a.b.c.d.e",           "a.b.c.d.f",                false),  // 25
        ("a.b.*.d",             "a.b.c.d",                  true),   // 26
        ("a.b.*.d",             "a.b.c.e",                  false),  // 27
        ("a.b.>",               "a.b",                      false),  // 28
        ("a.b",                 "a.b.c.d.>",               false),  // 29
        ("a.b.>.c",             "a.b.x.c",                  false),  // 30
        ("a.*.*",               "a.b",                      false),  // 31
        ("a.*",                 "a.b.c",                    false),  // 32
        ("metrics.cpu.load",    "metrics.*.load",           true),   // 33
        ("metrics.cpu.load",    "metrics.cpu.*",            true),   // 34
        ("metrics.cpu.load",    "metrics.>.load",           false),  // 35
        ("metrics.>",           "metrics",                  false),  // 36
        ("metrics.>",           "othermetrics.cpu",         false),  // 37
        ("*.*.>",               "a.b",                      false),  // 38
        ("*.*.>",               "a.b.c.d",                  true),   // 39
        ("a.b.c",               "*.*.*",                    true),   // 40
        ("a.b.c",               "*.*",                      false),  // 41
        ("alpha.*.>",           "alpha",                    false),  // 42
        ("alpha.*.>",           "alpha.beta",               false),  // 43
        ("alpha.*.>",           "alpha.beta.gamma",         true),   // 44
        ("alpha.*.>",           "beta.alpha.gamma",         false),  // 45
        ("foo-bar_baz",         "foo-bar_baz",              true),   // 46
        ("foo-bar_*",           "foo-bar_123",              false),  // 47
        ("foo-bar_*",           "foo-bar_*",                true),   // 48
        ("order-*",             "order-123",                false),  // 49
        ("hello.hey.*",         "hello.hey.>",              true)    // 50
    ]

    func test_TopicPatternMatcher() async throws {
        let realtime = try Realtime(
            apiKey: "<Key>",
            secret: "<Key>"
        )
        
        for (idx, testCase) in cases.enumerated() {
            let (pattern, topic, expected) = testCase
            let result = realtime.topicPatternMatcher(pattern, topic)
            XCTAssertEqual(
                result,
                expected,
                "Case \(idx + 1) failed — pattern: '\(pattern)', topic: '\(topic)', expected: \(expected), got: \(result)"
            )
        }
    }
    
    func test_topicValidationTest() async throws {
        let realtime = try Realtime(
            apiKey: "<Key>",
            secret: "<Key>"
        )
        
        let validTopics: [String] = [
                "foo",
                "foo.bar",
                "foo.bar.baz",
                "*",
                "foo.*",
                "*.bar",
                "foo.*.baz",
                ">",
                "foo.>",
                "foo.bar.>",
                "*.*.>",
                "alpha_beta",
                "alpha-beta",
                "alpha~beta",
                "abc123",
                "123abc",
                "~",
                "alpha.*.>",
                "alpha.*",
                "alpha.*.*",
                "-foo",
                "foo_bar-baz~qux",
                "A.B.C",
                "sensor.temperature",
                "metric.cpu.load",
                "foo.*.*",
                "foo.*.>",
                "foo_bar.*",
                "*.*",
                "metrics.>"
            ]
        
        for topic in validTopics {
            XCTAssertNoThrow(
                try TopicValidator.validate(topic),
                "Expected topic \"\(topic)\" to be valid, but the validator threw."
            )
            
            let valid = realtime.isTopicValid(topic)
            XCTAssertTrue(valid)
        }
        
        let invalidTopics: [String] = [
                "$foo",
                "foo$",
                "foo.$.bar",
                "foo..bar",
                ".foo",
                "foo.",
                "foo.>.bar",
                ">foo",
                "foo>bar",
                "foo.>bar",
                "foo.bar.>.",
                "foo bar",
                "foo/bar",
                "foo#bar",
                "",
                " ",
                "..",
                ".>",
                "foo..",
                ".",
                ">.",
                "foo,baz",
                "αbeta",
                "foo|bar",
                "foo;bar",
                "foo:bar",
                "foo%bar",
                "foo.*.>.bar",
                "foo.*.>.",
                "foo.*..bar",
                "foo.>.bar",
                "foo>"
            ]
        
        for topic in invalidTopics {
            await XCTAssertThrowsError(
                try TopicValidator.validate(topic),
                "Expected topic \"\(topic)\" to be invalid, but the validator did **not** throw."
            )
            
            let valid = realtime.isTopicValid(topic)
            XCTAssertFalse(valid)
        }
    }
}
