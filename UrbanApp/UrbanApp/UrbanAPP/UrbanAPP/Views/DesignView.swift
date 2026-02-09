//
//  DesignView.swift
//  UrbanAPP
//

import SwiftUI
import PhotosUI

struct DesignView: View {
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var captionText = ""
    @State private var resultImage: UIImage?
    @State private var fontUsed = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    var subscriptionManager = SubscriptionManager.shared
    @FocusState private var isTextFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        } else {
                            UploadPlaceholder(icon: "photo.badge.plus", text: "選擇底圖")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task { await loadImage(from: newValue) }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("要放在圖片上的文字")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("例如：自律是最好的投資", text: $captionText, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFocused)
                    }

                    Button {
                        isTextFocused = false
                        Task { await generateDesign() }
                    } label: {
                        ActionButtonLabel(text: "AI 時尚排版", icon: "wand.and.stars", isLoading: isLoading)
                    }
                    .disabled(selectedImage == nil || captionText.isEmpty || isLoading)

                    if let result = resultImage {
                        VStack(spacing: 12) {
                            Image(uiImage: result)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                            if !fontUsed.isEmpty {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundStyle(Color.brandGold)
                                    Text(fontUsed)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }

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
            .onTapGesture { isTextFocused = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isTextFocused = false }
                }
            }
            .navigationTitle("排版設計")
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
            resultImage = nil
        }
    }

    private func generateDesign() async {
        guard subscriptionManager.useFreeUse() else {
            showPaywall = true
            return
        }
        guard let image = selectedImage else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (result, _, usedFont) = try await APIService.shared.design(
                image: image, text: captionText
            )
            resultImage = result
            fontUsed = usedFont
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
