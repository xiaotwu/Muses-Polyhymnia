import SwiftUI

/// Native unavailable content with a page-specific explanation and recovery action.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let subtitle { Text(subtitle) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .musesAction(prominent: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
    }
}
