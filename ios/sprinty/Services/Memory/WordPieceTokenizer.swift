import Foundation

final class WordPieceTokenizer: Sendable {
    private let vocab: [String: Int32]
    private let unkTokenId: Int32
    private let clsTokenId: Int32
    private let sepTokenId: Int32
    private let padTokenId: Int32
    let maxSequenceLength: Int

    init(vocabURL: URL, maxSequenceLength: Int = 128) throws {
        let content = try String(contentsOf: vocabURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var vocab: [String: Int32] = [:]
        for (index, token) in lines.enumerated() {
            vocab[token] = Int32(index)
        }
        self.vocab = vocab
        self.unkTokenId = vocab["[UNK]"] ?? 100
        self.clsTokenId = vocab["[CLS]"] ?? 101
        self.sepTokenId = vocab["[SEP]"] ?? 102
        self.padTokenId = vocab["[PAD]"] ?? 0
        self.maxSequenceLength = maxSequenceLength
    }

    func tokenize(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        let lowered = text.lowercased()
        let words = splitOnPunctuation(lowered)
        var tokenIds: [Int32] = [clsTokenId]

        for word in words {
            let subTokens = wordPieceTokenize(word)
            tokenIds.append(contentsOf: subTokens)
            if tokenIds.count >= maxSequenceLength - 1 {
                break
            }
        }

        // Truncate to max_length - 1 (reserve space for [SEP])
        if tokenIds.count > maxSequenceLength - 1 {
            tokenIds = Array(tokenIds.prefix(maxSequenceLength - 1))
        }
        tokenIds.append(sepTokenId)

        let attentionMask = [Int32](repeating: 1, count: tokenIds.count)
            + [Int32](repeating: 0, count: maxSequenceLength - tokenIds.count)

        // Pad input_ids
        while tokenIds.count < maxSequenceLength {
            tokenIds.append(padTokenId)
        }

        return (tokenIds, attentionMask)
    }

    private func wordPieceTokenize(_ word: String) -> [Int32] {
        let chars = Array(word)
        var tokens: [Int32] = []
        var start = 0

        while start < chars.count {
            var end = chars.count
            var found = false

            while start < end {
                let substr: String
                if start > 0 {
                    substr = "##" + String(chars[start..<end])
                } else {
                    substr = String(chars[start..<end])
                }

                if let id = vocab[substr] {
                    tokens.append(id)
                    found = true
                    start = end
                    break
                }
                end -= 1
            }

            if !found {
                tokens.append(unkTokenId)
                start += 1
            }
        }

        return tokens
    }

    private func splitOnPunctuation(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""

        for char in text {
            if char.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else if char.isPunctuation || char.isSymbol {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                words.append(String(char))
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            words.append(current)
        }

        return words
    }
}
