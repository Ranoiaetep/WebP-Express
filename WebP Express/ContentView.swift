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
    @AppStorage("ConversionQuality") private var conversionQuality: Double = 80
    @AppStorage("ConversionCategory") private var conversionCategory: WebPEncoderConfig.Preset = .default
    @State private var operationQueue: OperationQueue = .init()
    @State var files: [FileModel] = []
    private let webPEncoder = WebPEncoder()

    var body: some View {
        VStack {
            HStack {
                Button(action: addFileViaPanel) {
                    Label("Add Files", systemImage: "plus.circle")
                        .padding()
                }
                .disabled(!operationQueue.operations.isEmpty)

                Spacer()

                Button(action: startConversionAction) {
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
        for url in urls where !files.map(\.url).contains(url){
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
                    files[index].state = .processing
                    let image = try? NSImage(data: .init(contentsOf: file.url))
                    let resultURL = file.url.deletingPathExtension().appendingPathExtension("webp")
                    operationQueue.addOperation {
                        guard let image,
                              let data = try? webPEncoder.encode(
                                image, config: .preset(conversionCategory, quality: Float(conversionQuality))
                              ),
                              (try? data.write(to: destinationDirectory.appending(component: resultURL.lastPathComponent))) != nil
                        else {
                            files[index].state = .fail
                            return
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
            TableColumn("Space Saved") { file in
                HStack {
                    Spacer()
                    Text(file.state == .success ? getSpaceSavedFormattedString(file.url) : "")
                }
            }
            .width(75)
        }
        .onDeleteCommand {
            files.removeAll { file in
                selectedFile.contains(file.id)
            }
            selectedFile.removeAll()
        }
    }

    private func getSpaceSavedFormattedString(_ url: URL) -> String {
        let destinationURL = url.deletingPathExtension().appendingPathExtension("webp")
        if let size1 = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           let size2 = try? destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            let rate = Double(size1 - size2) / Double(size1)
            return rate.formatted(.percent.precision(.fractionLength(0)))
        }
        return ""
    }
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
