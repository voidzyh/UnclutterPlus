import Foundation

enum OCRResult {
    case success(String)
    case failure(Error)
}

protocol OCREngine {
    func recognize(imageURL: URL) async -> OCRResult
}
