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

    func testTagMatchingUsesFirstSatisfiableTagSet() {
        // The empty tag set acts as a catch-all fallback.
        let preference = ReadPreference(mode: .secondary, tagSets: [["dc": "us-east"], [:]])

        XCTAssertTrue(preference.matches(memberTags: ["dc": "us-west"]))
        XCTAssertTrue(preference.matches(memberTags: nil))
    }
}
