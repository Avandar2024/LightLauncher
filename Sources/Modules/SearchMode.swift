import Foundation
import AppKit
import SwiftUI

// MARK: - 当前搜索项结构体（文件级）
struct CurrentQueryItem: DisplayableItem {
    let id = UUID()
    let title: String
    var subtitle: String? { "当前搜索" }
    var icon: NSImage? { nil }
}

// MARK: - 搜索模式控制器
@MainActor
class SearchModeController: NSObject, ModeStateController, ObservableObject {
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var currentQuery: String = ""
    
    var prefix: String? { "/s" }
    
    // 可显示项插槽
    var displayableItems: [any DisplayableItem] {
        var items: [any DisplayableItem] = []
        if !currentQuery.isEmpty {
            items.append(CurrentQueryItem(title: currentQuery))
        }
        items.append(contentsOf: searchHistory)
        return items
    }
    
    // 1. 触发条件
    func shouldActivate(for text: String) -> Bool {
        return text.hasPrefix("/s")
    }
    // 2. 进入模式
    func enterMode(with text: String, viewModel: LauncherViewModel) {
        currentQuery = extractQuery(from: text)
        searchHistory = SearchHistoryManager.shared.getMatchingHistory(for: currentQuery, limit: 10)
        viewModel.selectedIndex = 0
    }
    // 3. 处理输入
    func handleInput(_ text: String, viewModel: LauncherViewModel) {
        currentQuery = extractQuery(from: text)
        searchHistory = SearchHistoryManager.shared.getMatchingHistory(for: currentQuery, limit: 10)
        viewModel.selectedIndex = 0
    }
    // 4. 执行动作
    func executeAction(at index: Int, viewModel: LauncherViewModel) -> Bool {
        if index == 0 {
            // 当前搜索项
            let cleanText = currentQuery
            return openSearchURL(for: cleanText)
        } else if index > 0 && index <= searchHistory.count {
            let item = searchHistory[index - 1]
            return openSearchURL(for: item.query)
        }
        return false
    }
    // 5. 退出条件
    func shouldExit(for text: String, viewModel: LauncherViewModel) -> Bool {
        // 删除 /s 前缀或切换到其他模式时退出
        return !text.hasPrefix("/s")
    }
    // 6. 清理操作
    func cleanup(viewModel: LauncherViewModel) {
        searchHistory = []
        currentQuery = ""
    }
    // --- 辅助方法 ---
    private func extractQuery(from text: String) -> String {
        let prefix = "/s "
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    private func openSearchURL(for query: String) -> Bool {
        let engine = ConfigManager.shared.config.modes.defaultSearchEngine
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString: String
        switch engine {
        case "baidu":
            urlString = "https://www.baidu.com/s?wd=\(encodedQuery)"
        case "bing":
            urlString = "https://www.bing.com/search?q=\(encodedQuery)"
        case "google":
            fallthrough
        default:
            urlString = "https://www.google.com/search?q=\(encodedQuery)"
        }
        guard let url = URL(string: urlString) else { return false }
        SearchHistoryManager.shared.addSearch(query: query, searchEngine: engine)
        NSWorkspace.shared.open(url)
        return true
    }

    // MARK: - 便捷方法迁移自 LauncherViewModel extension
    func updateSearchHistory(_ items: [SearchHistoryItem]) {
        self.searchHistory = items
    }

    func executeSearchHistoryItem(at index: Int) -> Bool {
        guard index >= 0 && index < searchHistory.count else { return false }
        let item = searchHistory[index]
        return executeWebSearch(item.query)
    }

    func clearSearchHistory() {
        self.searchHistory = []
    }

    func removeSearchHistoryItem(_ item: SearchHistoryItem) {
        self.searchHistory.removeAll { $0.id == item.id }
    }

    func extractCleanSearchText(from text: String) -> String {
        let prefix = "/s "
        if text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func executeWebSearch(_ query: String) -> Bool {
        let configManager = ConfigManager.shared
        let engine = configManager.config.modes.defaultSearchEngine
        var searchEngine: String
        switch engine {
        case "baidu":
            searchEngine = "https://www.baidu.com/s?wd={query}"
        case "bing":
            searchEngine = "https://www.bing.com/search?q={query}"
        case "google":
            fallthrough
        default:
            searchEngine = "https://www.google.com/search?q={query}"
        }
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = searchEngine.replacingOccurrences(of: "{query}", with: encodedQuery)
        guard let url = URL(string: searchURL) else { return false }
        // 保存到搜索历史
        SearchHistoryManager.shared.addSearch(query: query, searchEngine: engine)
        NSWorkspace.shared.open(url)
        // 注意：不在此处 resetToLaunchMode，由外部控制
        return true
    }

    // 生成内容视图
    func makeContentView(viewModel: LauncherViewModel) -> AnyView {
        return AnyView(SearchHistoryView(viewModel: viewModel))
    }
    
    func makeRowView(for item: any DisplayableItem, isSelected: Bool, index: Int, viewModel: LauncherViewModel, handleItemSelection: @escaping (Int) -> Void) -> AnyView {
        return AnyView(EmptyView())
    }

    static func getHelpText() -> [String] {
        return [
            "Type after /s to search the web",
            "Press Enter to execute search",
            "Delete /s prefix to return to launch mode",
            "Press Esc to close"
        ]
    }
}
