import GitHub
import Tagged_Primitives

extension GitHub.Repository.Summary {
    init(
        fixture id: UInt64,
        name: Swift.String,
        archived: Bool = false,
        disabled: Bool = false,
        fork: Bool = false,
        visibility: GitHub.Repository.Visibility = .public
    ) {
        self.init(
            id: .init(id),
            name: .init(name),
            archived: archived,
            disabled: disabled,
            fork: fork,
            visibility: visibility
        )
    }
}
