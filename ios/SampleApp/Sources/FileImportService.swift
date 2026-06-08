import Foundation
import UniformTypeIdentifiers

enum FileImportServiceError: LocalizedError {
    case unsupportedType
    case inaccessibleFile

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Selected file is not a supported video."
        case .inaccessibleFile:
            return "Selected file could not be accessed."
        }
    }
}

final class FileImportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func importVideo(from url: URL) throws -> URL {
        let allowed = UTType.movie
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .nameKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            throw FileImportServiceError.inaccessibleFile
        }
        guard let contentType = values.contentType, contentType.conforms(to: allowed) else {
            throw FileImportServiceError.unsupportedType
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try makeImportDirectory(named: "files")
        let fileName = values.name ?? url.lastPathComponent
        let destination = uniqueDestination(in: directory, preferredFileName: fileName)
        try fileManager.copyItem(at: url, to: destination)
        return destination
    }

    private func makeImportDirectory(named name: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("vidsqueeze-sample", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func uniqueDestination(in directory: URL, preferredFileName: String) -> URL {
        let sanitized = preferredFileName.isEmpty ? UUID().uuidString + ".mp4" : preferredFileName
        let baseName = URL(fileURLWithPath: sanitized).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: sanitized).pathExtension
        return directory.appendingPathComponent("\(baseName)-\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)")
    }
}
