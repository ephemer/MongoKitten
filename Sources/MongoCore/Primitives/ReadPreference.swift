import BSON

/// Determines which members of a replica set (or which node behind a `mongos`) a read operation is routed to.
///
/// Read preferences mirror MongoDB's standard modes:
///
/// - ``Mode/primary``: Reads from the primary only. The default.
/// - ``Mode/primaryPreferred``: Reads from the primary if available, otherwise a secondary.
/// - ``Mode/secondary``: Reads from a secondary only.
/// - ``Mode/secondaryPreferred``: Reads from a secondary if available, otherwise the primary.
/// - ``Mode/nearest``: Reads from any available member, primary or secondary.
///
/// Optionally, ``tagSets`` can be used to further restrict which members are eligible based on their
/// replica set tags. Tag sets are evaluated in order; the first tag set that matches at least one
/// member is used. An empty tag set document (`[:]`) matches any member.
///
/// ```swift
/// // Route reads to a secondary in the "us-east" data center, falling back to any secondary
/// let preference = ReadPreference(
///     mode: .secondary,
///     tagSets: [["dc": "us-east"], [:]]
/// )
///
/// for try await user in users.find().readPreference(preference) {
///     print(user)
/// }
/// ```
public struct ReadPreference: Sendable, Codable, Equatable {
    /// The mode that determines which members are eligible for a read operation.
    public enum Mode: String, Sendable, Codable, Equatable {
        /// Reads from the primary only.
        case primary

        /// Reads from the primary if available, otherwise a secondary.
        case primaryPreferred

        /// Reads from a secondary only.
        case secondary

        /// Reads from a secondary if available, otherwise the primary.
        case secondaryPreferred

        /// Reads from any available member, primary or secondary.
        case nearest
    }

    /// The mode that determines which members are eligible for a read operation.
    public var mode: Mode

    /// An ordered list of tag sets used to further restrict eligible members.
    ///
    /// Tag sets are evaluated in order; the first tag set that matches at least one member is used.
    /// An empty tag set document (`[:]`) matches any member.
    public var tagSets: [Document]?

    public init(mode: Mode, tagSets: [Document]? = nil) {
        self.mode = mode
        self.tagSets = tagSets
    }

    /// Reads from the primary only. This is the default.
    public static let primary = ReadPreference(mode: .primary)

    /// Reads from the primary if available, otherwise a secondary.
    public static let primaryPreferred = ReadPreference(mode: .primaryPreferred)

    /// Reads from a secondary only.
    public static let secondary = ReadPreference(mode: .secondary)

    /// Reads from a secondary if available, otherwise the primary.
    public static let secondaryPreferred = ReadPreference(mode: .secondaryPreferred)

    /// Reads from any available member, primary or secondary.
    public static let nearest = ReadPreference(mode: .nearest)

    private enum CodingKeys: String, CodingKey {
        case mode
        case tagSets = "tags"
    }
}

extension ReadPreference {
    /// Whether this preference permits reading from a secondary member.
    public var allowsSecondaryReads: Bool {
        switch mode {
        case .primary:
            return false
        case .primaryPreferred, .secondary, .secondaryPreferred, .nearest:
            return true
        }
    }

    /// Whether this preference permits reading from the primary member.
    public var allowsPrimaryReads: Bool {
        switch mode {
        case .secondary:
            return false
        case .primary, .primaryPreferred, .secondaryPreferred, .nearest:
            return true
        }
    }

    /// Returns `true` if the given member tags satisfy this preference's tag sets.
    ///
    /// When no tag sets are configured, every member matches. Otherwise the member matches if it
    /// satisfies any one of the configured tag sets. A tag set is satisfied when every key/value pair
    /// in it is present in the member's tags.
    public func matches(memberTags: Document?) -> Bool {
        guard let tagSets, !tagSets.isEmpty else {
            return true
        }

        for tagSet in tagSets {
            if Self.tagSet(tagSet, isSatisfiedBy: memberTags) {
                return true
            }
        }

        return false
    }

    private static func tagSet(_ tagSet: Document, isSatisfiedBy memberTags: Document?) -> Bool {
        // An empty tag set matches any member.
        if tagSet.isEmpty {
            return true
        }

        guard let memberTags else {
            return false
        }

        for (key, value) in tagSet {
            guard
                let memberValue = memberTags[key],
                (memberValue as? String) == (value as? String)
            else {
                return false
            }
        }

        return true
    }
}
