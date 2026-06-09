import AVKit
import SwiftUI

struct CompressionHarnessView: View {
    @StateObject private var viewModel = CompressionHarnessViewModel()
    @State private var showsDocumentPicker = false
    @State private var showsPhotoPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sourceSection
                        previewSection
                        controlSection
                        progressSection
                        summarySection
                        logSection
                    }
                    .padding(20)
                }
                .disabled(viewModel.isLoadingSource)
                .blur(radius: viewModel.isLoadingSource ? 2 : 0)

                if viewModel.isLoadingSource {
                    sourceLoadingOverlay
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoadingSource)
            .navigationTitle("Native Harness")
            .alert(isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Compression Error"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showsDocumentPicker) {
                DocumentPicker { result in
                    showsDocumentPicker = false
                    if case .success(let url) = result {
                        viewModel.importFromDocument(url: url)
                    }
                }
            }
            .sheet(isPresented: $showsPhotoPicker) {
                PhotoPicker { result in
                    showsPhotoPicker = false
                    viewModel.importFromPhoto(result: result)
                }
            }
        }
    }

    private var sourceLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.15)
                Text("Loading source")
                    .font(.headline)
                Text(viewModel.sourceLoadingMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            .padding(24)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Source")
            Text(viewModel.selectedSourceLabel)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Pick From Files") {
                    showsDocumentPicker = true
                }
                .buttonStyle(HarnessPrimaryButtonStyle())
                .disabled(viewModel.isLoadingSource)

                Button("Pick From Photos") {
                    showsPhotoPicker = true
                }
                .buttonStyle(HarnessSecondaryButtonStyle())
                .disabled(viewModel.isLoadingSource)
            }

            if let source = viewModel.sourceSummary {
                summaryCard {
                    metricRow("Name", source.fileName)
                    metricRow("Resolution", MediaInspectorFormatter.dimensions(width: source.width, height: source.height))
                    metricRow("Duration", MediaInspectorFormatter.duration(source.durationMs))
                    metricRow("Codec", source.codecLabel)
                    metricRow("Audio", source.hasAudio ? "Keepable" : "No audio")
                    metricRow("Size", MediaInspectorFormatter.megabytes(source.sizeBytes))
                }
                .opacity(viewModel.isLoadingSource ? 0.45 : 1)
            }
        }
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Compression Controls")

            VStack(alignment: .leading, spacing: 8) {
                Text("Preset")
                    .font(.subheadline.weight(.semibold))
                presetSelector
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution Cap")
                    .font(.subheadline.weight(.semibold))
                resolutionPicker
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Codec")
                    .font(.subheadline.weight(.semibold))
                codecPicker
            }

            Toggle("Allow HEVC", isOn: $viewModel.allowHevc)
            Toggle("Keep Audio", isOn: $viewModel.keepAudio)
            Toggle("Keep Original If Larger", isOn: $viewModel.keepOriginalIfLarger)

            HStack {
                TextField("Max bitrate (bps)", text: $viewModel.maxBitrateText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Progress interval ms", text: $viewModel.progressIntervalMsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button("Start Compression") {
                    viewModel.compress()
                }
                .buttonStyle(HarnessPrimaryButtonStyle())
                .disabled(viewModel.isCompressing || viewModel.sourceSummary == nil)

                Button("Cancel") {
                    viewModel.cancelCompression()
                }
                .buttonStyle(HarnessSecondaryButtonStyle())
                .disabled(!viewModel.isCompressing)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Preview")

            VideoPreviewCard(
                title: "Original",
                url: viewModel.originalPreviewURL,
                detail: viewModel.sourceSummary.map {
                    "\($0.fileName) - \(MediaInspectorFormatter.dimensions(width: $0.width, height: $0.height))"
                } ?? "Pick a video to preview the source."
            )

            VideoPreviewCard(
                title: "Compressed",
                url: viewModel.compressedPreviewURL,
                detail: viewModel.outputSummary.map {
                    "\($0.fileName) - \(MediaInspectorFormatter.dimensions(width: $0.width, height: $0.height))"
                } ?? "Run compression to preview the output."
            )
        }
    }

    private var presetSelector: some View {
        HStack(spacing: 8) {
            ForEach(CompressionPresetOption.allCases) { option in
                Button {
                    viewModel.selectedPreset = option
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(viewModel.selectedPreset == option ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(viewModel.selectedPreset == option ? Color.blue : Color(.systemGray5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resolutionPicker: some View {
        Picker("Resolution Cap", selection: $viewModel.selectedResolutionCap) {
            ForEach(ResolutionCapOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var codecPicker: some View {
        Picker("Codec", selection: $viewModel.selectedCodec) {
            ForEach(ForceCodecOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Progress")
            summaryCard {
                metricRow("Phase", viewModel.phaseLabel)
                metricRow("Progress", "\(viewModel.progressPercent)%")
                ProgressView(value: Double(viewModel.progressPercent), total: 100)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Benchmark")

            if let output = viewModel.outputSummary {
                summaryCard {
                    metricRow("Output", output.fileName)
                    metricRow("Resolution", MediaInspectorFormatter.dimensions(width: output.width, height: output.height))
                    metricRow("Duration", MediaInspectorFormatter.duration(output.durationMs))
                    metricRow("Codec", output.codecLabel)
                    metricRow("Target Bitrate", MediaInspectorFormatter.bitrate(output.targetBitrate))
                    metricRow("Output Size", MediaInspectorFormatter.megabytes(output.sizeBytes))
                    metricRow("Attempts", "\(output.attempts)")
                    metricRow("Used Original", output.usedOriginalSource ? "Yes" : "No")
                }
            }

            if let benchmark = viewModel.benchmarkSummary {
                summaryCard {
                    metricRow("Elapsed", "\(benchmark.elapsedMs) ms")
                    metricRow("Source Size", MediaInspectorFormatter.megabytes(benchmark.sourceSizeBytes))
                    metricRow("Output Size", MediaInspectorFormatter.megabytes(benchmark.outputSizeBytes))
                    metricRow("Saved", MediaInspectorFormatter.megabytes(benchmark.savedBytes))
                    metricRow("Saved %", MediaInspectorFormatter.savedPercent(sourceBytes: benchmark.sourceSizeBytes, outputBytes: benchmark.outputSizeBytes))
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Session Log")

            summaryCard {
                if viewModel.logLines.isEmpty {
                    Text("No logs yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.logLines.prefix(12), id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func summaryCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HarnessPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HarnessSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color(.systemGray4) : Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct VideoPreviewCard: View {
    let title: String
    let url: URL?
    let detail: String

    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if url != nil {
                    Text("Playable")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            }

            Group {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 220)
                        .background(Color.black)
                } else {
                    ZStack {
                        Color.black.opacity(0.88)
                        VStack(spacing: 8) {
                            Image(systemName: "film")
                                .font(.title2)
                            Text("No video yet")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.white.opacity(0.82))
                    }
                    .frame(height: 160)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            configurePlayer(for: url)
        }
        .onChange(of: url) { newURL in
            configurePlayer(for: newURL)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func configurePlayer(for url: URL?) {
        player?.pause()
        player = url.map { AVPlayer(url: $0) }
    }
}
