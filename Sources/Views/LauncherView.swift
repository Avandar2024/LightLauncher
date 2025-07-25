import SwiftUI
import AppKit
import Combine

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            LauncherHeaderView(mode: viewModel.mode)
            
            // Search Box
            SearchBoxView(
                searchText: $viewModel.searchText,
                mode: viewModel.mode,
                onClear: {
                    viewModel.clearSearch()
                }
            )
            
            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 8)
            
            // Command Suggestions
            if viewModel.showCommandSuggestions {
                CommandSuggestionsView(
                    commands: viewModel.commandSuggestions,
                    selectedIndex: $viewModel.selectedIndex,
                    onCommandSelected: { command in
                        viewModel.applySelectedCommand(command)
                    }
                )
            } else if let controller = viewModel.activeController {
                controller.makeContentView(viewModel: viewModel)
            } else {
                EmptyView()
            }
        }
        .frame(width: 700, height: 500)
        .background(
            Color(NSColor.windowBackgroundColor)
        )
        .opacity(0.95)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
            KeyboardEventHandler.shared.startMonitoring()
        }
        .onDisappear {
            KeyboardEventHandler.shared.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = viewModel
            KeyboardEventHandler.shared.updateMode(viewModel.mode)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            KeyboardEventHandler.shared.viewModel = nil
        }
        .onChange(of: viewModel.mode) { newMode in
            KeyboardEventHandler.shared.updateMode(newMode)
        }
    }
}

@MainActor
struct ResultsListView: View {
    @ObservedObject var viewModel: LauncherViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    // --- 关键改动 ---
                    self.resultsListContent { index in
                        handleItemSelection(at: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
    
    private func handleItemSelection(at index: Int) {
        viewModel.selectedIndex = index
        if viewModel.executeSelectedAction() {
            // --- 关键改动 ---
            if viewModel.shouldHideWindowAfterAction {
                NotificationCenter.default.post(name: .hideWindow, object: nil)
            }
        }
    }

    @ViewBuilder
    func resultsListContent(handleItemSelection: @escaping (Int) -> Void) -> some View {
        if let controller = viewModel.controllers[viewModel.mode] {
            ForEach(Array(viewModel.displayableItems.enumerated()), id: \.offset) { index, item in
                controller.makeRowView(
                    for: item,
                    isSelected: index == viewModel.selectedIndex,
                    index: index,
                    viewModel: viewModel,
                    handleItemSelection: { _ in handleItemSelection(index) }
                )
                .id(index)
                .onTapGesture { handleItemSelection(index) }
            }
        } else {
            EmptyView()
        }
    }
}
