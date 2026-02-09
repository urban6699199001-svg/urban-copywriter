//
//  APIService.swift
//  UrbanAPP
//

import Foundation
import UIKit

/// URBAN API 客戶端 — 與 Python 後端通訊
final class APIService: Sendable {
    static let shared = APIService()

    private let baseURL = "https://urban-copywriter-82042159012.asia-east1.run.app/api/v1"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    // MARK: - Mode 1: 圖片 → 文案 (結構化)

    nonisolated func captionFromImage(_ image: UIImage) async throws -> [CaptionOption] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIServiceError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()
        let request = CaptionFromImageRequest(imageBase64: base64, mimeType: "image/jpeg")
        let response: CaptionOptionsResponse = try await post("/caption-from-image", body: request)
        return response.options
    }

    // MARK: - Mode 2: 文字 → 圖片

    nonisolated func generateImage(concept: String) async throws -> (UIImage, String?) {
        let request = GenerateImageRequest(concept: concept)
        let response: GenerateImageResponse = try await post("/generate-image", body: request)

        guard let data = Data(base64Encoded: response.imageBase64),
              let image = UIImage(data: data) else {
            throw APIServiceError.imageDecodeFailed
        }
        return (image, response.description)
    }

    // MARK: - Mode 2B: 人物照 + 背景替換

    nonisolated func replaceBackground(image: UIImage, scene: String) async throws -> (UIImage, String?) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIServiceError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()
        let request = ReplaceBackgroundRequest(imageBase64: base64, scene: scene, mimeType: "image/jpeg")
        let response: GenerateImageResponse = try await post("/replace-background", body: request)

        guard let data = Data(base64Encoded: response.imageBase64),
              let resultImage = UIImage(data: data) else {
            throw APIServiceError.imageDecodeFailed
        }
        return (resultImage, response.description)
    }

    // MARK: - Mode 3: 圖片 + 文字 → 排版

    nonisolated func design(image: UIImage, text: String, scene: String? = nil) async throws -> (UIImage, String, String) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIServiceError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()
        let request = DesignRequest(imageBase64: base64, text: text, scene: scene)
        let response: DesignResponse = try await post("/design", body: request)

        guard let data = Data(base64Encoded: response.imageBase64),
              let resultImage = UIImage(data: data) else {
            throw APIServiceError.imageDecodeFailed
        }
        return (resultImage, response.textUsed, response.fontUsed)
    }

    // MARK: - Mode 4: 熱門風格文案 (結構化)

    nonisolated func trendingCaption(topic: String) async throws -> [CaptionOption] {
        let request = TrendingRequest(topic: topic)
        let response: CaptionOptionsResponse = try await post("/trending", body: request)
        return response.options
    }

    // MARK: - Mode 5: 演算法分析 (結構化)

    nonisolated func analyzeAlgorithm(caption: String) async throws -> AlgorithmAnalysisResponse {
        let request = AlgorithmRequest(caption: caption)
        let response: AlgorithmAnalysisResponse = try await post("/algorithm", body: request)
        return response
    }

    // MARK: - 通用 POST

    private nonisolated func post<T: Codable & Sendable, R: Codable & Sendable>(_ path: String, body: T) async throws -> R {
        guard let url = URL(string: baseURL + path) else {
            throw APIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw APIServiceError.serverError(apiError.error)
            }
            throw APIServiceError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(R.self, from: data)
    }
}

enum APIServiceError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case imageConversionFailed
    case imageDecodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無效的 API 網址"
        case .invalidResponse: return "伺服器回應格式錯誤"
        case .httpError(let code): return "伺服器錯誤 (\(code))"
        case .serverError(let msg): return msg
        case .imageConversionFailed: return "圖片轉換失敗"
        case .imageDecodeFailed: return "圖片解碼失敗"
        }
    }
}
