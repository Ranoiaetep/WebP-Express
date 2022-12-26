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
    @State private var fileURLS: [URL] = []
    private let webPEncoder = WebPEncoder()
    @State private var queue: OperationQueue = .init()
    @State private var fileFinished: [URL:Bool] = [:]
    @State private var conversionStarted: Bool = false
    @State private var conversionFinished: Bool = false
    @State private var canAddFile: Bool = true
    @State private var conversionQuality: Float = 80
    @State private var conversionCategory: WebPEncoderConfig.Preset = .default

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    conversionFinished = false
                    fileURLS.removeAll { url in
                        fileFinished[url] ?? false
                    }
                    fileFinished.removeAll()
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.allowedContentTypes = [.image]
                    if panel.runModal() == .OK {
                        fileURLS.append(contentsOf: panel.urls)
                    }
                    conversionStarted = false
                } label: {
                    Label("Add Files", systemImage: "plus.circle")
                        .padding()
                }
                .disabled(!canAddFile)

                Spacer()

                if conversionFinished {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.title2)
                }

                Button(action: {
                    canAddFile = false
                    conversionStarted = true
                    for url in fileURLS {
                        let image = try! NSImage(data: Data(contentsOf: url))
                        queue.addOperation {
                            let data = try! webPEncoder.encode(image!, config: .preset(conversionCategory, quality: conversionQuality))
                            try! data.write(to: url.deletingPathExtension().appendingPathExtension("webp"))
                            fileFinished[url] = true
                        }
                    }
                }, label: {
                    Label("Start", systemImage: "play")
                        .padding()
                })
                .disabled(fileURLS.count == 0)
            }
            .frame(height: 40)
            .onChange(of: fileFinished) { newValue in
                if newValue.count == fileURLS.count {
                    canAddFile = true
                    conversionFinished = true
                }
            }
            Table(fileURLS) {
                TableColumn("Path", value: \.directory)
                TableColumn("Filename", value: \.lastPathComponent)
                TableColumn("Progress") { url in
                    if !conversionStarted {
                        EmptyView()
                    }
                    else if fileFinished[url] ?? false {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                    else {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(height: 10)
                    }
                }
            }
            GroupBox("Options") {
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
                        Text("Default").tag(WebPEncoderConfig.Preset.default)
                        Text("Picture").tag(WebPEncoderConfig.Preset.picture)
                        Text("Photo").tag(WebPEncoderConfig.Preset.photo)
                        Text("Drawing").tag(WebPEncoderConfig.Preset.drawing)
                        Text("Icon").tag(WebPEncoderConfig.Preset.icon)
                        Text("Text").tag(WebPEncoderConfig.Preset.text)
                    } label: {
                        Label("Preset", systemImage: "folder.badge.questionmark")
                    }
                }
                .padding(5)
            }
        }
        .padding()
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension URL {
    public var directory: String { deletingLastPathComponent().path(percentEncoded: false) }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
