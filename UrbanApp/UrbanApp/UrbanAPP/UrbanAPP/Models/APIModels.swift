//
//  APIModels.swift
//  UrbanAPP
//

import Foundation

// MARK: - Request Models

nonisolated struct CaptionFromImageRequest: Codable, Sendable {
    let imageBase64: String
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
    }
}

nonisolated struct GenerateImageRequest: Codable, Sendable {
    let concept: String
}

nonisolated struct ReplaceBackgroundRequest: Codable, Sendable {
    let imageBase64: String
    let scene: String
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case scene
        case mimeType = "mime_type"
    }
}

nonisolated struct DesignRequest: Codable, Sendable {
    let imageBase64: String
    let text: String
    let scene: String?

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case text
        case scene
    }
}

nonisolated struct TrendingRequest: Codable, Sendable {
    let topic: String
}

nonisolated struct AlgorithmRequest: Codable, Sendable {
    let caption: String
}

nonisolated struct FontRecommendRequest: Codable, Sendable {
    let text: String
    let scene: String?
}

// MARK: - Response Models (結構化)

/// 單一文案選項（圖片文案 / 熱門文案共用）
nonisolated struct CaptionOption: Codable, Sendable, Identifiable {
    let label: String
    let emoji: String
    let description: String
    let content: String

    var id: String { label }
}

/// 圖片文案 / 熱門文案 回應
nonisolated struct CaptionOptionsResponse: Codable, Sendable {
    let options: [CaptionOption]
}

/// 演算法分析的各區塊
nonisolated struct AlgorithmSection: Codable, Sendable, Identifiable {
    let label: String
    let emoji: String
    let content: String
    let score: String?

    var id: String { label }

    enum CodingKeys: String, CodingKey {
        case label, emoji, content, score
    }
}

/// 演算法分析回應
nonisolated struct AlgorithmAnalysisResponse: Codable, Sendable {
    let score: Int?
    let sections: [AlgorithmSection]
}

/// 圖片生成回應
nonisolated struct GenerateImageResponse: Codable, Sendable {
    let imageBase64: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case description
    }
}

/// 排版設計回應
nonisolated struct DesignResponse: Codable, Sendable {
    let imageBase64: String
    let textUsed: String
    let fontUsed: String
    let fontKey: String

    enum CodingKeys: String, CodingKey {
        case imageBase64 = "image_base64"
        case textUsed = "text_used"
        case fontUsed = "font_used"
        case fontKey = "font_key"
    }
}

nonisolated struct FontRecommendResponse: Codable, Sendable {
    let fontKey: String
    let fontName: String
    let fontStyle: String
    let bestFor: String

    enum CodingKeys: String, CodingKey {
        case fontKey = "font_key"
        case fontName = "font_name"
        case fontStyle = "font_style"
        case bestFor = "best_for"
    }
}

nonisolated struct APIError: Codable, Sendable {
    let error: String
}
