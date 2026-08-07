public import JSON

extension Workspace.Verification.Inventory {
    /// The effective-inventory digest a verification run was measured
    /// against — or the recorded reason there is none.
    ///
    /// **Why a type and not a string.** The control plane's envelope
    /// schema already states the rule: the digest may be the literal
    /// `"unmeasured"`, but only accompanied by a cause. Expressed as a
    /// bare `String`, "unmeasured with no cause" is a value the receipt can
    /// hold, serialize, and seal — and it did: the private-verification
    /// sweep dispatched exactly that literal, with no cause, for every
    /// subject in the fleet. As a type, that state does not exist: an
    /// unmeasured digest carries its cause or it cannot be constructed.
    ///
    /// **Why the JSON shape is two keys, not one.** `inventoryDigest` and
    /// `inventoryDigestCause` are what the envelope
    /// (`Private.Verification.Envelope`) already reads. This type is a
    /// Swift-side invariant over an existing wire schema, not a new wire
    /// schema — a receipt written before this type existed still parses,
    /// provided it was honest.
    public enum Digest: Equatable, Sendable {
        /// A real digest of a real population: 64 lowercase hex digits, as
        /// ``Workspace/Inventory/Effective/Output/Limb/digest`` produces.
        case measured(Swift.String)
        /// No digest was established, and this is why. The cause is not
        /// decoration: it is the difference between "the inventory is
        /// empty" and "this dispatcher is not credentialed to see the
        /// inventory", which are opposite facts that a bare `"unmeasured"`
        /// renders identical.
        case unmeasured(cause: Swift.String)
    }
}

extension Workspace.Verification.Inventory.Digest {
    /// The `inventoryDigest` field's value.
    public var token: Swift.String {
        switch self {
        case .measured(let digest): digest
        case .unmeasured: Token.unmeasured
        }
    }

    /// The `inventoryDigestCause` field's value, present exactly when
    /// nothing was measured.
    public var cause: Swift.String? {
        switch self {
        case .measured: nil
        case .unmeasured(let cause): cause
        }
    }

    /// Reconstructs the typed value from the two wire fields, refusing
    /// every combination the envelope refuses.
    public init(token: Swift.String, cause: Swift.String?) throws(Error) {
        if token == Token.unmeasured {
            guard let cause, !cause.isEmpty else { throw .unmeasuredWithoutCause }
            self = .unmeasured(cause: cause)
            return
        }
        guard cause == nil || cause?.isEmpty == true else { throw .measuredWithCause }
        guard token.count == 64, token.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
            throw .notLowercaseHex64
        }
        self = .measured(token)
    }
}

extension Workspace.Verification.Inventory.Digest: JSON.Serializable {
    /// Serialized as one string — the `inventoryDigest` field itself. The
    /// cause travels beside it in the enclosing object (see
    /// ``Workspace/Verification/Receipt``), because that is the shape the
    /// envelope reads; this conformance exists so the field can be written
    /// and read like any other.
    public static func serialize(_ value: Self) -> JSON { value.token.json }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let token = try Swift.String(json: json)
        guard token != Token.unmeasured else {
            throw .typeMismatch(
                expected: "a measured digest, or an unmeasured token with its cause",
                got: "unmeasured without a cause"
            )
        }
        do throws(Error) {
            return try Self(token: token, cause: nil)
        } catch {
            throw .typeMismatch(expected: "64 lowercase hex digits", got: token)
        }
    }
}
