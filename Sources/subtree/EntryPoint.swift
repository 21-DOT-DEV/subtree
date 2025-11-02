import SubtreeLib

// Entry point for the subtree CLI executable
// This is a thin wrapper that delegates to SubtreeLib for all functionality
@main
struct EntryPoint {
    static func main() async {
        await SubtreeCommand.main()
    }
}
