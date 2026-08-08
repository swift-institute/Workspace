extension Workspace {
    /// The shared content-addressed receipt discipline every Institute
    /// receipt in this module uses.
    ///
    /// A receipt seals an observation by digest: two receipts describing the
    /// same facts serialize to the same canonical text and therefore digest
    /// identically, and a receipt that cites another does so by that digest,
    /// never by prose. ``Sealed`` is the one conformance point; conformers
    /// get ``Sealed/canonical`` and ``Sealed/digest`` for free and are
    /// required to add nothing beyond their own `JSON.Serializable` shape.
    public enum Receipt {}
}
