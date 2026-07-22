import GitHub

extension GitHub.Page.Number {
    init(fixture value: UInt) {
        guard let number = Self(rawValue: value) else {
            preconditionFailure("Invalid fixture page number")
        }
        self = number
    }
}

extension GitHub.Organization.Repositories.Traversal.Limit {
    init(fixture pages: UInt, items: UInt) {
        guard
            let pageLimit = Pages(rawValue: pages),
            let itemLimit = Items(rawValue: items)
        else { preconditionFailure("Invalid fixture traversal limit") }
        self.init(pages: pageLimit, items: itemLimit)
    }
}
