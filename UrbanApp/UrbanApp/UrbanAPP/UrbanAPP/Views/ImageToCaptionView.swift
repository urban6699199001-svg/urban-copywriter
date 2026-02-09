//
//  ImageToCaptionView.swift
//  UrbanAPP
//

import SwiftUI
import PhotosUI

struct ImageToCaptionView: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var captionOptions: [CaptionOption] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        } else {
                            UploadPlaceholder(icon: "photo.badge.plus", text: "選擇一張照片")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task { await loadImage(from: newValue) }
                    }

                    if selectedImage != nil {
                        Button {
                            Task { await generateCaption() }
                        } label: {
                            ActionButtonLabel(text: "生成文案", icon: "sparkles", isLoading: isLoading)
                        }
                        .disabled(isLoading)
                    }

                    if !captionOptions.isEmpty {
                        VStack(spacing: 4) {
                            HStack {
                                Text("AI 生成文案")
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text("\(captionOptions.count) 個選項")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("點「複製」即可直接貼上使用")
                                .font(.caption)
                                .foregroundStyle(Color.brandGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(captionOptions) { option in
                            CaptionOptionCard(
                                emoji: option.emoji,
                                label: option.label,
                                description: option.description,
                                content: option.content
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("圖片文案")
            .alert("錯誤", isPresented: $showError) {
                Button("確定") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
            captionOptions = []
        }
    }

    private func generateCaption() async {
        guard subscriptionManager.useFreeUse() else {
            showPaywall = true
            return
        }
        guard let image = selectedImage else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            captionOptions = try await APIService.shared.captionFromImage(image)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
