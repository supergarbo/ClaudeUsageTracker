import Foundation

/// Service for watching Claude data directories for changes
@Observable
class FileWatcherService {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var directoryDescriptors: [Int32] = []
    private var debounceTask: Task<Void, Never>?

    /// Callback when files change (debounced)
    var onFilesChanged: (() -> Void)?

    /// Start watching Claude data directories
    func startWatching() {
        stopWatching()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let directories = [
            home.appendingPathComponent(".config/claude/projects"),
            home.appendingPathComponent(".claude/projects")
        ]

        for directory in directories {
            watchDirectory(directory)
        }
    }

    /// Watch a directory and its subdirectories for changes
    private func watchDirectory(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        // Watch the main directory
        addWatcher(for: url)

        // Also watch subdirectories
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let subURL = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: subURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                addWatcher(for: subURL)
            }
        }
    }

    private func addWatcher(for url: URL) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            print("Failed to open directory for watching: \(url.path)")
            return
        }

        directoryDescriptors.append(fd)

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        sources.append(source)
    }

    /// Handle file change with debouncing
    private func handleFileChange() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            // Wait 500ms to batch rapid changes
            try? await Task.sleep(nanoseconds: 500_000_000)

            if !Task.isCancelled {
                onFilesChanged?()
            }
        }
    }

    /// Stop watching all directories
    func stopWatching() {
        debounceTask?.cancel()
        debounceTask = nil

        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        directoryDescriptors.removeAll()
    }

    deinit {
        stopWatching()
    }
}
