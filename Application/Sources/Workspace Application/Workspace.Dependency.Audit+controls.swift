private import Byte_Primitives
private import Byte_Primitives_Standard_Library_Integration

extension Workspace.Dependency.Audit {
    func controls() -> Workspace.Dependency.Controls {
        let positiveSource =
            #".package(url: "https://github.com/control/third-party.git", branch: "main")"#
        let negativeSource =
            #"// .package(url: "https://github.com/control/commented.git", branch: "main")"#
        let positive: Swift.Bool
        do throws(Workspace.Dependency.Parser.Error) {
            positive = try parser.parse([Byte](positiveSource.utf8)) == [
                .url(
                    "https://github.com/control/third-party.git",
                    line: 1
                )
            ]
        } catch {
            positive = false
        }
        let negative: Swift.Bool
        do throws(Workspace.Dependency.Parser.Error) {
            negative = try parser.parse([Byte](negativeSource.utf8)).isEmpty
        } catch {
            negative = false
        }
        return .init(positive: positive, negative: negative)
    }
}
