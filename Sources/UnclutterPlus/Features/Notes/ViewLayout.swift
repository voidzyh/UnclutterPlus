import Foundation

enum ViewLayout: String, CaseIterable {
    case sidebar = "Sidebar"
    case grid = "Grid"
    case list = "List"
    
    var systemImage: String {
        switch self {
        case .sidebar:
            return "sidebar.left"
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}