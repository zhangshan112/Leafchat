import SwiftUI
import Vision
import FoundationModels

// MARK: - Generable output types (iOS 26+)

@available(iOS 26, *)
@Generable
struct PlantIdentificationResult {
    @Guide(description: "The most likely common English name of the plant, e.g. 'Monstera Deliciosa'. Use title case.")
    var commonName: String

    @Guide(description: "The Latin scientific name, e.g. 'Monstera deliciosa'. Return an empty string if uncertain.")
    var scientificName: String

    @Guide(description: "Your confidence level based on the clarity and plant-specificity of the vision labels provided")
    var confidence: IdentificationConfidence

    @Guide(description: "One concise, practical care tip for this plant in a single sentence")
    var careTip: String
}

@available(iOS 26, *)
@Generable
enum IdentificationConfidence {
    case high
    case medium
    case low
}

// MARK: - Service

@available(iOS 26, *)
@Observable
final class PlantIdentificationService {

    enum State {
        case idle
        case analyzing
        case matched(plant: PlantWikiPlant, result: PlantIdentificationResult)
        case error(String)
    }

    var state: State = .idle

    private let languageModel = SystemLanguageModel.default

    var modelAvailability: SystemLanguageModel.Availability {
        languageModel.availability
    }

    // MARK: - Public

    func identify(image: UIImage) async {
        state = .analyzing
        do {
            let visionLabels = try await runVisionClassification(image: image)
            let result: PlantIdentificationResult

            if languageModel.isAvailable {
                result = try await runFoundationModels(visionLabels: visionLabels)
            } else {
                result = visionOnlyFallback(labels: visionLabels)
            }

            let matched = PlantWikiModel.plant(named: result.commonName)
                ?? PlantWikiModel.plant(named: result.scientificName)
                ?? PlantWikiModel.fallbackPlant(named: result.commonName)

            state = .matched(plant: matched, result: result)
        } catch {
            state = .error("Could not identify the plant. Try a clearer, well-lit photo.")
        }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Vision

    private func runVisionClassification(image: UIImage) async throws -> [(label: String, confidence: Float)] {
        guard let ciImage = CIImage(image: image) else { return [] }
        let request = ClassifyImageRequest()
        let observations = try await request.perform(on: ciImage)
        return observations
            .filter { $0.hasMinimumPrecision(0.1, forRecall: 0.8) }
            .prefix(10)
            .map { ($0.identifier, $0.confidence) }
    }

    // MARK: - Foundation Models

    private func runFoundationModels(
        visionLabels: [(label: String, confidence: Float)]
    ) async throws -> PlantIdentificationResult {
        let session = LanguageModelSession()
        let labelsText = visionLabels
            .map { "\($0.label) (\(Int($0.confidence * 100))%)" }
            .joined(separator: ", ")

        let response = try await session.respond(
            generating: PlantIdentificationResult.self
        ) {
            """
            You are an expert botanist specializing in common houseplants and garden plants.

            A photo was analyzed by the Vision framework and produced these classification labels (with confidence scores):
            \(labelsText)

            Identify the most likely plant. Prioritize common indoor houseplants when labels are ambiguous.
            Assign high confidence only when plant-specific labels (e.g. 'monstera', 'pothos') appear with strong scores.
            """
        }
        return response.content
    }

    // MARK: - Vision-only fallback (Apple Intelligence unavailable)

    private func visionOnlyFallback(labels: [(label: String, confidence: Float)]) -> PlantIdentificationResult {
        let plantKeywords: [String: String] = [
            "monstera":     "Monstera Deliciosa",
            "pothos":       "Golden Pothos",
            "succulent":    "Echeveria",
            "cactus":       "Bunny Ear Cactus",
            "orchid":       "Phalaenopsis Orchid",
            "aloe":         "Aloe Vera",
            "peace lily":   "Peace Lily",
            "fiddle":       "Fiddle Leaf Fig",
            "philodendron": "Heartleaf Philodendron",
            "calathea":     "Calathea Orbifolia",
            "dracaena":     "Dracaena",
            "aglaonema":    "Chinese Evergreen",
            "zz plant":     "ZZ Plant",
            "snake plant":  "Snake Plant",
            "spider plant": "Spider Plant",
        ]

        for (label, _) in labels {
            for (keyword, name) in plantKeywords {
                if label.localizedCaseInsensitiveContains(keyword) {
                    return PlantIdentificationResult(
                        commonName: name,
                        scientificName: "",
                        confidence: .medium,
                        careTip: "View the full care guide in our Plant Encyclopedia."
                    )
                }
            }
        }

        let topLabel = labels.first?.label.capitalized ?? "Plant"
        return PlantIdentificationResult(
            commonName: topLabel,
            scientificName: "",
            confidence: .low,
            careTip: "Enable Apple Intelligence in Settings for more accurate identification."
        )
    }
}
