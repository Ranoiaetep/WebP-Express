//
//  ContentView.swift
//  WebP Test
//
//  Created by Peter Cong on 12/25/22.
//

import SwiftUI
import PhotosUI
import WebP
import UserNotifications

struct ContentView: View {
    @AppStorage("ConversionQuality") private var conversionQuality: Double = 80
    @AppStorage("ConversionCategory") private var conversionCategory: WebPEncoderConfig.Preset = .default
    @AppStorage("UserNotificationAuthorized") private var userNotificationAuthorized: Bool = false
    @State private var operationQueue: OperationQueue = .init()
    @State var files: [FileModel] = []
    @State private var totalFileSizeSaved = 0
    private let webPEncoder = WebPEncoder()
    private let userNotificationCenter = UNUserNotificationCenter.current()

    var body: some View {
        VStack {
            HStack {
                Button(action: addFileViaPanel) {
                    Label("Add Files", systemImage: "plus.circle")
                        .padding()
                }
                .disabled(!operationQueue.operations.isEmpty)

                Spacer()

                Button{
                    userNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        userNotificationAuthorized = granted
                        if let error { print(error) }
                    }
                    startConversionAction()
                } label: {
                    Label("Start", systemImage: "play")
                        .padding()
                }
                .disabled(!operationQueue.operations.isEmpty ||
                          files.map(\.state).filter({ $0 != .success }).isEmpty
                )
            }
            .frame(height: 40)

            FileTableView(files: $files)
            .dropDestination(for: URL.self, action: addFileViaDrop(urls:_:))

            OptionsView(conversionQuality: $conversionQuality, conversionCategory: $conversionCategory)
        }
        .padding()
        .onChange(of: files.map(\.state)) { newValue in
            userNotificationCenter.getNotificationSettings { setting in
                if newValue.count > 0 && setting.alertSetting == .enabled && setting.soundSetting == .enabled{
                    let content = UNMutableNotificationContent()
                    if newValue.allSatisfy({ $0 == .success }) {
                        content.title = "Job Done"
                        content.subtitle = "\(getFormattedFileSizeFromInt(totalFileSizeSaved)) saved!"
                        content.sound = .default
                    }
                    else if newValue.allSatisfy({ $0 == .success || $0 == .fail }) {
                        content.title = "Job Failed"
                        content.subtitle = "\(newValue.filter({ $0 != .success }).count) conversion failed!"
                        content.sound = .defaultCritical
                    }
                    userNotificationCenter.add(.init(identifier: UUID().uuidString, content: content, trigger: nil))
                }
            }
        }
        .onAppear {
            userNotificationCenter.getNotificationSettings { setting in
                print(setting)
            }
        }
    }

    private func addFileViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.message = "Select Files"
        panel.prompt = "Select"
        panel.beginSheetModal(for: NSApplication.shared.windows.first!) { modal in
            if modal == .OK {
                addFileAction(urls: panel.urls)
            }
        }
    }

    private func addFileViaDrop(urls: [URL], _: CGPoint) -> Bool {
        let urls = Array(Set(urls)).filter { url in
            return (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) ?? false
        }
        addFileAction(urls: urls)
        return true
    }

    private func addFileAction(urls: [URL]) {
        files.removeAll { $0.state == .success }
        for url in urls where !files.map(\.url).contains(url) {
            files.append(FileModel(url: url))
        }
        files.sort(by: <)
    }

    private func startConversionAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Save"
        panel.message = "Save Files At..."

        panel.beginSheetModal(for: NSApplication.shared.windows.first!) { modal in
            if modal == .OK {
                let destinationDirectory = panel.url!
                for (index, file) in files.enumerated().filter({ $0.element.state != .success }) {
                    let image = try? NSImage(data: .init(contentsOf: file.url))
                    let resultURL = file.url.deletingPathExtension().appendingPathExtension("webp")
                    operationQueue.addOperation {
                        files[index].state = .processing
                        guard let image,
                              let data = try? webPEncoder.encode(
                                image, config: .preset(conversionCategory, quality: Float(conversionQuality))
                              ),
                              (try? data.write(to: destinationDirectory.appending(component: resultURL.lastPathComponent))) != nil
                        else {
                            files[index].state = .fail
                            return
                        }
                        if let originalSize = try? file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                           let newSize = try? resultURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            totalFileSizeSaved += originalSize - newSize
                        }
                        files[index].state = .success
                    }
                }
            }
        }
    }
}

struct FileTableView: View {
    @Binding var files: [FileModel]
    @State private var selectedFile: Set<FileModel.ID> = []

    var body: some View {
        Table(files, selection: $selectedFile) {
            TableColumn("Filename", value: \.url.lastPathComponent)
                .width(min: 200, ideal: 300)
            TableColumn("") { file in
                HStack {
                    Spacer()
                    switch file.state {
                    case .unstarted:
                        EmptyView()
                    case .success:
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    case .fail:
                        Image(systemName: "x.circle")
                            .foregroundColor(.red)
                    case .processing:
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                }
            }
            .width(33)
            TableColumn("Size") { file in
                if file.state == .success {
                    Text(getFormattedFileSizeFromInt(getNewFileSize(file.url)))
                }
            }
            .width(70)
            TableColumn("Savings") { file in
                HStack {
                    Spacer()
                    Text(file.state == .success ? getSpaceSavedFormattedString(file.url) : "")
                }
            }
            .width(50)
        }
        .onDeleteCommand {
            files.removeAll { file in
                selectedFile.contains(file.id)
            }
            selectedFile.removeAll()
        }
    }

    private func getNewFileSize(_ url: URL) -> Int? {
        let destinationURL = url.deletingPathExtension().appendingPathExtension("webp")
        return try? destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    private func getSpaceSavedFormattedString(_ url: URL) -> String {
        if let size1 = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           let size2 = getNewFileSize(url) {
            let rate = Double(size1 - size2) / Double(size1)
            return rate.formatted(.percent.precision(.fractionLength(0)))
        }
        return ""
    }
}

private func getFormattedFileSizeFromInt(_ value: Int?) -> String {
    if let value {
        var valueDouble = Double(value)
        let sizeLables = ["B", "KB", "MB", "GB"]
        var currentLableIndex = 0
        while valueDouble > 1024 && currentLableIndex < 3 {
            valueDouble /= 1024
            currentLableIndex += 1
        }
        return "\(valueDouble.formatted(.number.precision(.significantDigits(4)))) \(sizeLables[currentLableIndex])"
    }
    return ""
}

struct OptionsView: View {
    @Binding var conversionQuality: Double
    @Binding var conversionCategory: WebPEncoderConfig.Preset

    var body: some View {
        GroupBox {
            HStack {
                HStack {
                    Slider(value: $conversionQuality, in: 50.0...100.0, step: 5) {
                        Label("Quality", systemImage: "photo.on.rectangle")
                    }
                    Text(conversionQuality.formatted(.number.precision(.fractionLength(0))))
                        .frame(width: 50)
                }
                Divider()
                    .frame(height: 20)
                Picker(selection: $conversionCategory) {
                    ForEach(WebPEncoderConfig.Preset.allCases, id: \.hashValue) { preset in
                        Text(preset.description.capitalized).tag(preset)
                    }
                } label: {
                    Label("Preset", systemImage: "folder.badge.questionmark")
                }
            }
            .padding(5)
        } label: {
            Label("Options", systemImage: "gearshape")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var files: [FileModel] = [
        .init(url: .applicationDirectory, state: .success),
        .init(url: .documentsDirectory, state: .processing),
        .init(url: .downloadsDirectory, state: .unstarted),
        .init(url: .desktopDirectory, state: .fail)
    ]
    static var previews: some View {
        ContentView(files: files)
    }
}
