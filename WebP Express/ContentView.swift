//
//  ContentView.swift
//  WebP Test
//
//  Created by Peter Cong on 12/25/22.
//

import SwiftUI
import PhotosUI
import WebP

struct ContentView: View {
    private let webPEncoder = WebPEncoder()
    @State private var queue: OperationQueue = .init()
    @State private var files: [FileModel] = []
    @AppStorage("ConversionQuality") private var conversionQuality: Double = 80
    @AppStorage("ConversionCategory") private var conversionCategory: WebPEncoderConfig.Preset = .default
    @State private var selectedFile: Set<FileModel.ID> = []

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: addFileViaPanel) {
                    Label("Add Files", systemImage: "plus.circle")
                        .padding()
                }
                .disabled(!queue.operations.isEmpty)

                Spacer()

                Button(action: startConversionAction) {
                    Label("Start", systemImage: "play")
                        .padding()
                }
                .disabled(!queue.operations.isEmpty ||
                          files.map(\.state).filter{ $0 != .success }.isEmpty
                )
            }
            .frame(height: 40)
            Table(files, selection: $selectedFile) {
                TableColumn("Filename", value: \.url.lastPathComponent)
                    .width(min: 200, ideal: 300)
                TableColumn("Path", value: \.url.directory)
                    .width(min: 200)
                TableColumn("Space Saved") { file in
                    Text(file.state == .success ? getSpaceSavedFormattedString(file.url) : "")
                }
                    .width(100)
                TableColumn("") { file in
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
                                .frame(height: 10)
                    }
                }
                    .width(20)
            }
            .onDeleteCommand {
                files.removeAll { file in
                    selectedFile.contains(file.id)
                }
                selectedFile.removeAll()
            }
            .dropDestination(for: URL.self, action: addFileViaDrop(urls:_:))

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
        .padding()
    }

    private func addFileViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            addFileAction(urls: panel.urls)
        }
    }

    private func addFileViaDrop(urls: [URL], _: CGPoint) -> Bool {
        let urls = Array(Set(urls)).filter { url in
            return (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .image)) ?? false
        }.sorted()
        addFileAction(urls: urls)
        return true
    }

    private func addFileAction(urls: [URL]) {
        files.removeAll { file in
            file.state != .unstarted
        }
        for url in urls {
            if !files.map(\.url).contains(url) {
                files.append(FileModel(url: url))
            }
        }
    }

    private func startConversionAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: NSApplication.shared.windows.first!) { modal in
            if modal == .OK {
                let destinationDirectory = panel.url!
                for (index, file) in files.enumerated().filter({ $0.element.state != .success }) {
                    files[index].state = .processing
                    let image = try! NSImage(data: .init(contentsOf: file.url))
                    let resultURL = file.url.deletingPathExtension().appendingPathExtension("webp")
                    queue.addOperation {
                        let data = try? webPEncoder.encode(image!, config: .preset(conversionCategory, quality: Float(conversionQuality)))
                        if let data {
                            try! data.write(to: destinationDirectory.appending(component: resultURL.lastPathComponent))
                            files[index].state = .success
                        } else {
                            files[index].state = .fail
                        }
                    }
                }
            }
        }
    }

    private func getSpaceSavedFormattedString(_ url: URL) -> String {
        if let attribute1 = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)),
           let attribute2 = try? FileManager.default.attributesOfItem(atPath: url.deletingPathExtension().appendingPathExtension("webp").path(percentEncoded: false)) {
            let size1 = attribute1[.size]! as! NSNumber
            let size2 = attribute2[.size]! as! NSNumber
            let rate = (size1.doubleValue - size2.doubleValue) / size1.doubleValue
            return rate.formatted(.percent.precision(.fractionLength(0)))
        }
        return ""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
