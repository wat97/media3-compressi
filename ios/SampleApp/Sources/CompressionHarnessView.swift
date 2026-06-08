import SwiftUI

struct CompressionHarnessView: View {
    @StateObject private var viewModel = CompressionHarnessViewModel()
    @State private var showsDocumentPicker = false
    @State private var showsPhotoPicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sourceSection
                    controlSection
                    progressSection
                    summarySection
                    logSection
                }
                .padding(20)
            }
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

                Button("Pick From Photos") {
                    showsPhotoPicker = true
                }
                .buttonStyle(HarnessSecondaryButtonStyle())
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
            }
        }
    }

    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Compression Controls")

            Picker("Preset", selection: $viewModel.selectedPreset) {
                ForEach(CompressionPresetOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Picker("Resolution Cap", selection: $viewModel.selectedResolutionCap) {
                ForEach(ResolutionCapOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Picker("Codec", selection: $viewModel.selectedCodec) {
                ForEach(ForceCodecOption.allCases) { option in
                    Text(option.title).tag(option)
                }
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
