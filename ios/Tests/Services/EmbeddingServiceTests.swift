import Foundation
import Testing
@testable import sprinty

@Suite("EmbeddingService Tests")
struct EmbeddingServiceTests {
    @Test("WordPiece tokenizer loads vocab and tokenizes text")
    func tokenizerLoadsAndTokenizes() throws {
        let url = try EmbeddingTestHelpers.vocabURL()
        let tokenizer = try WordPieceTokenizer(vocabURL: url)

        let (inputIds, attentionMask) = tokenizer.tokenize("Hello world")

        #expect(inputIds[0] == 101) // [CLS]
        #expect(inputIds.count == 128)
        #expect(attentionMask.count == 128)

        let tokenCount = attentionMask.filter { $0 == 1 }.count
        #expect(tokenCount > 2)
        #expect(tokenCount < 128)
    }

    @Test("WordPiece tokenizer handles empty string")
    func tokenizerEmptyString() throws {
        let url = try EmbeddingTestHelpers.vocabURL()
        let tokenizer = try WordPieceTokenizer(vocabURL: url)

        let (inputIds, attentionMask) = tokenizer.tokenize("")

        #expect(inputIds[0] == 101) // [CLS]
        #expect(inputIds[1] == 102) // [SEP]
        let tokenCount = attentionMask.filter { $0 == 1 }.count
        #expect(tokenCount == 2)
    }

    @Test("EmbeddingService generates 384-dim embeddings and semantic similarity works")
    func embeddingServiceFullPipeline() throws {
        let model = try EmbeddingTestHelpers.modelURL()
        let vocab = try EmbeddingTestHelpers.vocabURL()
        let service = try EmbeddingService(modelURL: model, vocabURL: vocab)

        // Test 1: Basic embedding generation
        let emb1 = try service.generateEmbedding(for: "I want to improve my productivity")
        #expect(emb1.count == 384)
        let nonZero = emb1.filter { !$0.isNaN && $0 != 0.0 }.count
        #expect(nonZero > 0, "Embedding should have non-zero values")
        let nanCount1 = emb1.filter { $0.isNaN }.count
        #expect(nanCount1 == 0, "First embedding has \(nanCount1) NaN values")

        // Test 2: Second call should also work
        let emb2 = try service.generateEmbedding(for: "I love programming")
        #expect(emb2.count == 384)
        let nanCount2 = emb2.filter { $0.isNaN }.count
        #expect(nanCount2 == 0, "Second embedding has \(nanCount2) NaN values")

        // Test 3: Different texts should produce different embeddings
        let diff = zip(emb1, emb2).map { abs($0 - $1) }.reduce(0, +)
        #expect(diff > 0.1, "Different texts should produce different embeddings")

        // Test 4: Semantic similarity
        let embSimilar = try service.generateEmbedding(for: "I enjoy coding")
        let embDissimilar = try service.generateEmbedding(for: "Quantum physics is complex")

        let simToSimilar = cosineSimilarity(emb2, embSimilar)
        let simToDissimilar = cosineSimilarity(emb2, embDissimilar)

        #expect(simToSimilar > simToDissimilar,
            "Similar texts should have higher similarity (\(simToSimilar)) than dissimilar (\(simToDissimilar))")
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard normA > 0 && normB > 0 else { return 0 }
        return dotProduct / (normA * normB)
    }
}
