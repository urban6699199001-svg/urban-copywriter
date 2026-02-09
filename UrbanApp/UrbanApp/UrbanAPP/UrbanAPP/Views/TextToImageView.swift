//
//  TextToImageView.swift
//  UrbanAPP
//

import SwiftUI
import PhotosUI

struct TextToImageView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("模式", selection: $selectedTab) {
                    Text("AI 生圖").tag(0)
                    Text("背景替換").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                if selectedTab == 0 {
                    ConceptToImageTab()
                } else {
                    BackgroundReplaceTab()
                }
            }
            .navigationTitle("AI 生圖")
        }
    }
}

// MARK: - Tab 1: 文字概念 → AI 生圖

struct ConceptToImageTab: View {
    @State private var concept = ""
    @State private var generatedImage: UIImage?
    @State private var description: String?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述你想要的畫面")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("例如：財務自由的早晨", text: $concept, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }

                Button {
                    isFocused = false
                    Task { await generateImage() }
                } label: {
                    ActionButtonLabel(text: "生成圖片", icon: "paintbrush.pointed.fill", isLoading: isLoading)
                }
                .disabled(concept.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                if let image = generatedImage {
                    VStack(spacing: 12) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                        Button {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        } label: {
                            Label("儲存到相簿", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if let desc = description, !desc.isEmpty {
                            ResultCard(title: "設計概念", content: desc)
                        }
                    }
                }
            }
            .padding()
        }
        .onTapGesture { isFocused = false }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isFocused = false }
            }
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func generateImage() async {
        guard subscriptionManager.useFreeUse() else {
            showPaywall = true
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let (image, desc) = try await APIService.shared.generateImage(concept: concept)
            generatedImage = image
            description = desc
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Tab 2: 人物照片 + 背景替換

struct BackgroundReplaceTab: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scene = ""
    @State private var resultImage: UIImage?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isFocused: Bool

    private let sceneSuggestions = [
        "巴黎鐵塔前",
        "東京涉谷街頭",
        "紐約時代廣場",
        "馬爾地夫海灘",
        "瑞士雪山",
        "杜拜帆船酒店",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    } else {
                        UploadPlaceholder(icon: "person.crop.rectangle", text: "選擇人物照片")
                    }
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    Task { await loadImage(from: newValue) }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("想要的背景場景")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("例如：巴黎鐵塔前", text: $scene)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sceneSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                scene = suggestion
                                isFocused = false
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }

                Button {
                    isFocused = false
                    Task { await replaceBackground() }
                } label: {
                    ActionButtonLabel(text: "替換背景", icon: "wand.and.stars", isLoading: isLoading)
                }
                .disabled(selectedImage == nil || scene.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                if let result = resultImage {
                    VStack(spacing: 12) {
                        Image(uiImage: result)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                        Button {
                            UIImageWriteToSavedPhotosAlbum(result, nil, nil, nil)
                        } label: {
                            Label("儲存到相簿", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .onTapGesture { isFocused = false }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isFocused = false }
            }
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
            resultImage = nil
        }
    }

    private func replaceBackground() async {
        guard subscriptionManager.useFreeUse() else {
            showPaywall = true
            return
        }
        guard let image = selectedImage else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (result, _) = try await APIService.shared.replaceBackground(image: image, scene: scene)
            resultImage = result
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
