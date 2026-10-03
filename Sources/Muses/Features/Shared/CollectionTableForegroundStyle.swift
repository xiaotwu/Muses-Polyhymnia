import SwiftUI

/// Keep the reading palette until native selection requires semantic contrast.
struct CollectionTableForegroundStyle: ShapeStyle {
    let color: Color
    var secondary = false

    init(_ color: Color, secondary: Bool = false) {
        self.color = color
        self.secondary = secondary
    }

    func resolve(in environment: EnvironmentValues) -> AnyShapeStyle {
        if environment.backgroundProminence == .increased {
            return secondary ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
        }
        return AnyShapeStyle(color)
    }
}
