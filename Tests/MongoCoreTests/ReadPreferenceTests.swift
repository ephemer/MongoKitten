import XCTest
import BSON
import MongoCore

final class ReadPreferenceTests: XCTestCase {
    func testEncodesModeOnly() throws {
        let document = try BSONEncoder().encode(ReadPreference.secondary)
        XCTAssertEqual(document["mode"] as? String, "secondary")
        XCTAssertNil(document["tags"])
    }

    func testEncodesTagSets() throws {
        let preference = ReadPreference(mode: .secondaryPreferred, tagSets: [["dc": "us-east"], [:]])
        let document = try BSONEncoder().encode(preference)

        XCTAssertEqual(document["mode"] as? String, "secondaryPreferred")

        let tags = document["tags"] as? Document
        XCTAssertNotNil(tags)
        XCTAssertEqual(tags?.values.count, 2)
        XCTAssertEqual((tags?[0] as? Document)?["dc"] as? String, "us-east")
    }

    func testRoundTrips() throws {
        let preference = ReadPreference(mode: .nearest, tagSets: [["region": "eu"]])
        let document = try BSONEncoder().encode(preference)
        let decoded = try BSONDecoder().decode(ReadPreference.self, from: document)
        XCTAssertEqual(decoded, preference)
    }

    func testModePermissions() {
        XCTAssertFalse(ReadPreference.primary.allowsSecondaryReads)
        XCTAssertTrue(ReadPreference.primary.allowsPrimaryReads)

        XCTAssertTrue(ReadPreference.secondary.allowsSecondaryReads)
        XCTAssertFalse(ReadPreference.secondary.allowsPrimaryReads)

        for preference in [ReadPreference.primaryPreferred, .secondaryPreferred, .nearest] {
            XCTAssertTrue(preference.allowsPrimaryReads)
            XCTAssertTrue(preference.allowsSecondaryReads)
        }
    }

    func testTagMatchingWithoutTagSetsMatchesEverything() {
        XCTAssertTrue(ReadPreference.secondary.matches(memberTags: ["dc": "us-east"]))
        XCTAssertTrue(ReadPreference.secondary.matches(memberTags: nil))
    }

    func testTagMatchingRequiresAllPairs() {
        let preference = ReadPreference(mode: .secondary, tagSets: [["dc": "us-east", "rack": "1"]])

        XCTAssertTrue(preference.matches(memberTags: ["dc": "us-east", "rack": "1", "extra": "x"]))
        XCTAssertFalse(preference.matches(memberTags: ["dc": "us-east"]))
        XCTAssertFalse(preference.matches(memberTags: ["dc": "us-west", "rack": "1"]))
        XCTAssertFalse(preference.matches(memberTags: nil))
    }

    func testParsesFromConnectionString() throws {
        let settings = try ConnectionSettings("mongodb://localhost/db?readPreference=secondaryPreferred")
        XCTAssertEqual(settings.readPreference, .secondaryPreferred)
        // Consumed query params should not leak into queryParameters.
        XCTAssertNil(settings.queryParameters["readPreference"])
    }

    func testParsesTagsFromConnectionString() throws {
        let settings = try ConnectionSettings("mongodb://localhost/db?readPreference=secondary&readPreferenceTags=dc:us-east,rack:1")
        XCTAssertEqual(settings.readPreference?.mode, .secondary)

        let tagSet = settings.readPreference?.tagSets?.first
        XCTAssertEqual(tagSet?["dc"] as? String, "us-east")
        XCTAssertEqual(tagSet?["rack"] as? String, "1")
    }

    func testParsesOrderedTagSetsFromConnectionString() throws {
        let settings = try ConnectionSettings(
            "mongodb://localhost/db?readPreference=secondaryPreferred&readPreferenceTags=dc:us-east,rack:1&readPreferenceTags=dc:us-west&readPreferenceTags="
        )
        XCTAssertEqual(settings.readPreference?.mode, .secondaryPreferred)

        let tagSets = settings.readPreference?.tagSets
        XCTAssertEqual(tagSets?.count, 3)

        // Order must be preserved.
        XCTAssertEqual((tagSets?[0])?["dc"] as? String, "us-east")
        XCTAssertEqual((tagSets?[0])?["rack"] as? String, "1")
        XCTAssertEqual((tagSets?[1])?["dc"] as? String, "us-west")
        // The trailing empty tag set is the catch-all fallback.
        XCTAssertEqual(tagSets?[2], [:])
    }

    func testNoReadPreferenceByDefault() throws {
        let settings = try ConnectionSettings("mongodb://localhost/db")
        XCTAssertNil(settings.readPreference)
    }

    func testTagMatchingUsesFirstSatisfiableTagSet() {
        // The empty tag set acts as a catch-all fallback.
        let preference = ReadPreference(mode: .secondary, tagSets: [["dc": "us-east"], [:]])

        XCTAssertTrue(preference.matches(memberTags: ["dc": "us-west"]))
        XCTAssertTrue(preference.matches(memberTags: nil))
    }
}
