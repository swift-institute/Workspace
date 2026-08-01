internal import File_System
#if canImport(Security)
private import Security
#endif

extension Workspace.GitHub.App {
    /// RS256 signing of the application assertion.
    ///
    /// The Institute has no cryptography package, and Foundation is barred, so
    /// this reaches the platform key facility directly through CoreFoundation
    /// types. That is the whole of the dependency: no key material crosses a
    /// process boundary, is written anywhere, or appears in a process
    /// argument.
    ///
    /// When a public Institute signing package exists, this file is the only
    /// thing that changes — the assertion, the mint flow, and the cache all
    /// take the signature as bytes.
    enum Signature {}
}

extension Workspace.GitHub.App.Signature {
    /// Signs `message` with `key` under RSASSA-PKCS1-v1_5 over SHA-256.
    static func rs256(
        message: [Byte],
        key: Workspace.GitHub.App.Key
    ) throws(Workspace.GitHub.App.Error) -> [Byte] {
        #if canImport(Security)
        let attributes = try dictionary(
            keys: [kSecAttrKeyType, kSecAttrKeyClass],
            values: [kSecAttrKeyTypeRSA, kSecAttrKeyClassPrivate]
        )
        let keyData = try data(key.der)
        let messageData = try data(message)

        var failure: Unmanaged<CFError>?
        guard
            let secKey = unsafe SecKeyCreateWithData(keyData, attributes, &failure)
        else {
            unsafe failure?.release()
            throw .malformedKey
        }
        guard
            let signature = unsafe SecKeyCreateSignature(
                secKey,
                .rsaSignatureMessagePKCS1v15SHA256,
                messageData,
                &failure
            )
        else {
            // The CFError's own message can name the key facility's view of
            // the key; report the failure without it.
            unsafe failure?.release()
            throw .signing("the platform key facility rejected the assertion")
        }

        let count = CFDataGetLength(signature)
        var bytes = [Byte](repeating: 0, count: count)
        unsafe bytes.withUnsafeMutableBufferPointer { buffer in
            guard let base = unsafe buffer.baseAddress else { return }
            unsafe CFDataGetBytes(signature, CFRangeMake(0, count), base)
        }
        return bytes
        #else
        throw .unsupportedPlatform
        #endif
    }
}

#if canImport(Security)
extension Workspace.GitHub.App.Signature {
    /// A `CFData` over `bytes`, copied rather than borrowed so its lifetime is
    /// independent of the caller's array.
    private static func data(_ bytes: [Byte]) throws(Workspace.GitHub.App.Error) -> CFData {
        let value = unsafe bytes.withUnsafeBufferPointer { buffer in
            unsafe CFDataCreate(kCFAllocatorDefault, buffer.baseAddress, buffer.count)
        }
        guard let value else { throw .signing("cannot allocate the request payload") }
        return value
    }

    /// A `CFDictionary` of CoreFoundation constants.
    ///
    /// Built by hand because the usual `[CFString: Any] as CFDictionary`
    /// bridge is Foundation's, and this target does not import Foundation.
    private static func dictionary(
        keys: [CFString],
        values: [CFString]
    ) throws(Workspace.GitHub.App.Error) -> CFDictionary {
        var keyCallbacks = kCFTypeDictionaryKeyCallBacks
        var valueCallbacks = kCFTypeDictionaryValueCallBacks
        var keyPointers = unsafe keys.map {
            unsafe UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque())
                as UnsafeRawPointer?
        }
        var valuePointers = unsafe values.map {
            unsafe UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque())
                as UnsafeRawPointer?
        }
        let value = unsafe CFDictionaryCreate(
            kCFAllocatorDefault,
            &keyPointers,
            &valuePointers,
            keys.count,
            &keyCallbacks,
            &valueCallbacks
        )
        guard let value else { throw .signing("cannot allocate the key attributes") }
        return value
    }
}
#endif
