import Foundation
import PhotosUI
import UniformTypeIdentifiers

enum PhotoImportServiceError: LocalizedError {
    case unsupportedItem
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedItem:
            return "Selected photo item is not a supported video."
        case .loadFailed:
            return "Selected photo item could not be loaded."
        }
    }
}

final class PhotoImportService: @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func importVideo(from result: PHPickerResult, completion: @escaping (Result<URL, Error>) -> Void) {
        let provider = result.itemProvider
        guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            completion(.failure(PhotoImportServiceError.unsupportedItem))
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [fileManager] sourceURL, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let sourceURL else {
                completion(.failure(PhotoImportServiceError.loadFailed))
                return
            }

            do {
                let directory = try Self.makeImportDirectory(fileManager: fileManager)
                let destination = directory.appendingPathComponent("\(UUID().uuidString).\(sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension)")
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: sourceURL, to: destination)
                completion(.success(destination))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func makeImportDirectory(fileManager: FileManager) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("vidsqueeze-sample", isDirectory: true)
            .appendingPathComponent("photos", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
