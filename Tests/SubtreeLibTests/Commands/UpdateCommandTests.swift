import Testing
import Foundation
@testable import SubtreeLib

/// Tests for ReportEntry JSON encoding and enriched fields
@Suite("ReportEntry Tests")
struct UpdateCommandTests {
    
    // MARK: - Helpers
    
    /// Encode a ReportEntry to a JSON dictionary for easy assertion
    private func encodeToDict(_ entry: ReportEntry) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    
    // MARK: - Tag-based Behind Entry
    
    @Test("Behind tag-based entry has all enriched fields populated")
    func testBehindTagBasedEntry() throws {
        let entry = ReportEntry(
            name: "secp256k1",
            status: .behind,
            currentTag: "v0.3.1",
            latestTag: "v0.4.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/bitcoin-core/secp256k1",
            error: nil,
            latestCommit: "a1b2c3d4",
            compareURL: "https://github.com/bitcoin-core/secp256k1/compare/v0.3.1...v0.4.0",
            branchName: "subtree/secp256k1-v0.4.0",
            extractions: ["{include,src}/**/*.{c,h} → Sources/libsecp256k1/ (excluding **/{bench,test}*)"],
            prTitle: "chore(deps): update subtree secp256k1 to v0.4.0",
            prBody: "## Update subtree `secp256k1`"
        )
        
        let dict = try encodeToDict(entry)
        
        #expect(dict["latest_commit"] as? String == "a1b2c3d4")
        #expect(dict["compare_url"] as? String == "https://github.com/bitcoin-core/secp256k1/compare/v0.3.1...v0.4.0")
        #expect(dict["branch_name"] as? String == "subtree/secp256k1-v0.4.0")
        #expect(dict["pr_title"] as? String == "chore(deps): update subtree secp256k1 to v0.4.0")
        #expect((dict["pr_body"] as? String)?.contains("## Update subtree `secp256k1`") == true)
        
        let extractions = dict["extractions"] as? [String]
        #expect(extractions?.count == 1)
        #expect(extractions?.first?.contains("→") == true)
    }
    
    // MARK: - Branch-based Behind Entry
    
    @Test("Behind branch-based entry has latestCommit and branchName with short SHA")
    func testBehindBranchBasedEntry() throws {
        let entry = ReportEntry(
            name: "swift-crypto",
            status: .behind,
            currentTag: nil,
            latestTag: nil,
            currentCommit: "aabbccdd",
            branch: "main",
            remote: "https://github.com/apple/swift-crypto",
            error: nil,
            latestCommit: "11223344",
            compareURL: "https://github.com/apple/swift-crypto/compare/aabbccddaabbccddaabbccddaabbccddaabbccdd...1122334411223344112233441122334411223344",
            branchName: "subtree/swift-crypto-11223344",
            extractions: nil,
            prTitle: "chore(deps): update subtree swift-crypto to 11223344",
            prBody: "## Update subtree `swift-crypto`"
        )
        
        let dict = try encodeToDict(entry)
        
        #expect(dict["latest_commit"] as? String == "11223344")
        #expect(dict["branch_name"] as? String == "subtree/swift-crypto-11223344")
        #expect(dict["pr_title"] as? String == "chore(deps): update subtree swift-crypto to 11223344")
        
        // current_commit should also be present for branch-based
        #expect(dict["current_commit"] as? String == "aabbccdd")
        
        // Tag fields should be absent (nil)
        #expect(dict["current_tag"] == nil)
        #expect(dict["latest_tag"] == nil)
    }
    
    // MARK: - Up-to-date Entry
    
    @Test("Up-to-date entry omits all enriched fields")
    func testUpToDateEntry() throws {
        let entry = ReportEntry(
            name: "mylib",
            status: .upToDate,
            currentTag: "v1.0.0",
            latestTag: "v1.0.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/user/mylib",
            error: nil
        )

        let dict = try encodeToDict(entry)

        // New fields are absent when nil (not encoded)
        #expect(dict["latest_commit"] == nil)
        #expect(dict["compare_url"] == nil)
        #expect(dict["branch_name"] == nil)
        #expect(dict["extractions"] == nil)
        #expect(dict["pr_title"] == nil)
        #expect(dict["pr_body"] == nil)
    }
    
    // MARK: - Error Entry
    
    @Test("Error entry omits all enriched fields")
    func testErrorEntry() throws {
        let entry = ReportEntry(
            name: "badlib",
            status: .error,
            currentTag: "v1.0.0",
            latestTag: nil,
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/user/badlib",
            error: "No tags found on remote"
        )

        let dict = try encodeToDict(entry)

        // New fields are absent when nil
        #expect(dict["latest_commit"] == nil)
        #expect(dict["compare_url"] == nil)
        #expect(dict["branch_name"] == nil)
        #expect(dict["extractions"] == nil)
        #expect(dict["pr_title"] == nil)
        #expect(dict["pr_body"] == nil)
        #expect(dict["error"] as? String == "No tags found on remote")
    }
    
    // MARK: - Branch Name Format
    
    @Test("branchName format for tag-based: subtree/<name>-<tag>")
    func testBranchNameTagBased() throws {
        let entry = ReportEntry(
            name: "secp256k1",
            status: .behind,
            currentTag: "v0.3.1",
            latestTag: "v0.4.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/bitcoin-core/secp256k1",
            error: nil,
            latestCommit: "a1b2c3d4",
            compareURL: nil,
            branchName: "subtree/secp256k1-v0.4.0",
            extractions: nil,
            prTitle: nil,
            prBody: nil
        )
        
        let dict = try encodeToDict(entry)
        #expect(dict["branch_name"] as? String == "subtree/secp256k1-v0.4.0")
    }
    
    @Test("branchName format for branch-based: subtree/<name>-<short_sha>")
    func testBranchNameBranchBased() throws {
        let entry = ReportEntry(
            name: "swift-crypto",
            status: .behind,
            currentTag: nil,
            latestTag: nil,
            currentCommit: "aabbccdd",
            branch: "main",
            remote: "https://github.com/apple/swift-crypto",
            error: nil,
            latestCommit: "11223344",
            compareURL: nil,
            branchName: "subtree/swift-crypto-11223344",
            extractions: nil,
            prTitle: nil,
            prBody: nil
        )
        
        let dict = try encodeToDict(entry)
        #expect(dict["branch_name"] as? String == "subtree/swift-crypto-11223344")
    }
    
    // MARK: - PR Title Format
    
    @Test("prTitle format: chore(deps): update subtree <name> to <version>")
    func testPRTitleFormat() throws {
        let tagEntry = ReportEntry(
            name: "secp256k1",
            status: .behind,
            currentTag: "v0.3.1",
            latestTag: "v0.4.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/bitcoin-core/secp256k1",
            error: nil,
            latestCommit: "a1b2c3d4",
            compareURL: nil,
            branchName: nil,
            extractions: nil,
            prTitle: "chore(deps): update subtree secp256k1 to v0.4.0",
            prBody: nil
        )
        
        let dict = try encodeToDict(tagEntry)
        #expect(dict["pr_title"] as? String == "chore(deps): update subtree secp256k1 to v0.4.0")
    }
    
    // MARK: - PR Body Content
    
    @Test("prBody contains expected markdown sections")
    func testPRBodyContent() throws {
        let prBody = """
        ## Update subtree `secp256k1` (v0.3.1 → v0.4.0)
        
        ### Changes
        - **Previous**: v0.3.1
        - **Updated**: v0.4.0
        - **Compare**: [v0.3.1...v0.4.0](https://github.com/bitcoin-core/secp256k1/compare/v0.3.1...v0.4.0)
        
        ### Extractions Applied
        - `{include,src}/**/*.{c,h}` → `Sources/libsecp256k1/` (excluding `**/{bench,test}*`)
        
        ---
        > 🤖 This PR was automatically created by the subtree update workflow.
        > Review the changes and merge when ready.
        """
        
        let entry = ReportEntry(
            name: "secp256k1",
            status: .behind,
            currentTag: "v0.3.1",
            latestTag: "v0.4.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/bitcoin-core/secp256k1",
            error: nil,
            latestCommit: "a1b2c3d4",
            compareURL: "https://github.com/bitcoin-core/secp256k1/compare/v0.3.1...v0.4.0",
            branchName: "subtree/secp256k1-v0.4.0",
            extractions: ["{include,src}/**/*.{c,h} → Sources/libsecp256k1/ (excluding **/{bench,test}*)"],
            prTitle: "chore(deps): update subtree secp256k1 to v0.4.0",
            prBody: prBody
        )
        
        let dict = try encodeToDict(entry)
        let body = dict["pr_body"] as? String
        #expect(body?.contains("## Update subtree `secp256k1`") == true)
        #expect(body?.contains("### Changes") == true)
        #expect(body?.contains("### Extractions Applied") == true)
        #expect(body?.contains("v0.3.1 → v0.4.0") == true)
        #expect(body?.contains("automatically created") == true)
    }
    
    // MARK: - Extractions Formatting
    
    @Test("extractions formatting with from/to/exclude")
    func testExtractionsFormatting() throws {
        let entry = ReportEntry(
            name: "mylib",
            status: .behind,
            currentTag: "v1.0.0",
            latestTag: "v2.0.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/user/mylib",
            error: nil,
            latestCommit: "a1b2c3d4",
            compareURL: nil,
            branchName: nil,
            extractions: [
                "{include,src}/**/*.{c,h} → Sources/libsecp256k1/ (excluding **/{bench,test}*, **/precomputed_*)",
                "docs/**/*.md → Documentation/"
            ],
            prTitle: nil,
            prBody: nil
        )
        
        let dict = try encodeToDict(entry)
        let extractions = dict["extractions"] as? [String]
        #expect(extractions?.count == 2)
        #expect(extractions?[0].contains("→") == true)
        #expect(extractions?[0].contains("excluding") == true)
        #expect(extractions?[1] == "docs/**/*.md → Documentation/")
    }
    
    // MARK: - Backward Compatibility
    
    @Test("Existing fields preserved when new fields are nil")
    func testBackwardCompatibility() throws {
        let entry = ReportEntry(
            name: "mylib",
            status: .behind,
            currentTag: "v1.0.0",
            latestTag: "v2.0.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/user/mylib",
            error: nil
        )
        
        let dict = try encodeToDict(entry)
        
        // Existing fields preserved
        #expect(dict["name"] as? String == "mylib")
        #expect(dict["status"] as? String == "behind")
        #expect(dict["current_tag"] as? String == "v1.0.0")
        #expect(dict["latest_tag"] as? String == "v2.0.0")
        #expect(dict["remote"] as? String == "https://github.com/user/mylib")
        
        // New fields absent when nil
        #expect(dict["latest_commit"] == nil)
        #expect(dict["compare_url"] == nil)
        #expect(dict["branch_name"] == nil)
        #expect(dict["extractions"] == nil)
        #expect(dict["pr_title"] == nil)
        #expect(dict["pr_body"] == nil)
    }
    
    // MARK: - JSON Roundtrip
    
    @Test("ReportEntry JSON keys use snake_case")
    func testJSONKeysSnakeCase() throws {
        let entry = ReportEntry(
            name: "test",
            status: .behind,
            currentTag: "v1.0.0",
            latestTag: "v2.0.0",
            currentCommit: nil,
            branch: nil,
            remote: "https://github.com/user/test",
            error: nil,
            latestCommit: "abcd1234",
            compareURL: "https://github.com/user/test/compare/v1.0.0...v2.0.0",
            branchName: "subtree/test-v2.0.0",
            extractions: ["src/**/*.swift → Sources/"],
            prTitle: "chore(deps): update subtree test to v2.0.0",
            prBody: "## Update"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Verify snake_case keys
        #expect(jsonString.contains("\"latest_commit\""))
        #expect(jsonString.contains("\"compare_url\""))
        #expect(jsonString.contains("\"branch_name\""))
        #expect(jsonString.contains("\"extractions\""))
        #expect(jsonString.contains("\"pr_title\""))
        #expect(jsonString.contains("\"pr_body\""))
        
        // Verify no camelCase leaks
        #expect(!jsonString.contains("\"latestCommit\""))
        #expect(!jsonString.contains("\"compareURL\""))
        #expect(!jsonString.contains("\"branchName\""))
        #expect(!jsonString.contains("\"prTitle\""))
        #expect(!jsonString.contains("\"prBody\""))
    }
}
