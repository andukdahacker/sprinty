import CoreML
import Foundation

protocol EmbeddingServiceProtocol: Sendable {
    func generateEmbedding(for text: String) throws -> [Float]
}

// @unchecked Sendable: thread-safe via NSLock protecting MLModel.prediction() calls
final class EmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {
    private let model: MLModel
    private let tokenizer: WordPieceTokenizer
    private let lock = NSLock()

    init(modelURL: URL, vocabURL: URL, maxSequenceLength: Int = 128) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
        self.tokenizer = try WordPieceTokenizer(vocabURL: vocabURL, maxSequenceLength: maxSequenceLength)
    }

    func generateEmbedding(for text: String) throws -> [Float] {
        let (inputIds, attentionMask) = tokenizer.tokenize(text)
        let seqLen = tokenizer.maxSequenceLength

        let inputIdsArray = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)
        let maskArray = try MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32)

        for i in 0..<seqLen {
            inputIdsArray[[0, NSNumber(value: i)] as [NSNumber]] = NSNumber(value: inputIds[i])
            maskArray[[0, NSNumber(value: i)] as [NSNumber]] = NSNumber(value: attentionMask[i])
        }

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: maskArray),
        ])

        let prediction = try lock.withLock {
            try model.prediction(from: provider)
        }

        // Find the embedding output — try known names
        let outputNames = ["embedding", "output_embedding", "output"]
        var embeddingArray: MLMultiArray?
        for name in outputNames {
            if let val = prediction.featureValue(for: name)?.multiArrayValue {
                embeddingArray = val
                break
            }
        }
        // If none found, try the first available output
        if embeddingArray == nil {
            for name in prediction.featureNames {
                if let val = prediction.featureValue(for: name)?.multiArrayValue {
                    embeddingArray = val
                    break
                }
            }
        }
        guard let embeddingArray else {
            throw EmbeddingServiceError.invalidOutput
        }

        // Model outputs shape [1, 384]
        let dim = 384
        guard embeddingArray.count >= dim else {
            throw EmbeddingServiceError.unexpectedDimension(embeddingArray.count)
        }

        var embedding = [Float](repeating: 0, count: dim)
        let isMultiDim = embeddingArray.shape.count == 2
        for i in 0..<dim {
            let key: [NSNumber] = isMultiDim ? [0, NSNumber(value: i)] : [NSNumber(value: i)]
            embedding[i] = embeddingArray[key].floatValue
        }

        return embedding
    }
}

enum EmbeddingServiceError: Error, LocalizedError {
    case invalidOutput
    case unexpectedDimension(Int)

    var errorDescription: String? {
        switch self {
        case .invalidOutput: "Model returned invalid output"
        case .unexpectedDimension(let dim): "Expected 384 dimensions, got \(dim)"
        }
    }
}
