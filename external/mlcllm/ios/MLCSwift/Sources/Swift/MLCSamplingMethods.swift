import Foundation

extension MLCEngine {
    // Temperature scaling + optional top-k + nucleus (top-p) sampling over logits.
    public func sampleWithNucleus(
        logits: [Double],
        temperature: Double,
        topP: Double,
        topK: Int = 0
    ) -> Int {
        // Guard against degenerate inputs
        guard !logits.isEmpty else { return 0 }

        // Temperature scaling (avoid divide-by-zero)
        let invTemp = 1.0 / max(temperature, 1e-8)
        let scaled = logits.map { $0 * invTemp }

        // Numerically stable softmax
        let maxL = scaled.max() ?? 0
        let expScores = scaled.map { exp($0 - maxL) }
        let sum = expScores.reduce(0, +)
        if sum <= 0 {
            // Fallback: pick argmax if probabilities collapse
            return logits.indices.max(by: { logits[$0] < logits[$1] }) ?? 0
        }
        let probs = expScores.map { $0 / sum }

        // Sort by probability descending
        let sorted = probs.enumerated().sorted { $0.element > $1.element }

        // Optional top-k filtering
        let kFiltered = topK > 0 ? Array(sorted.prefix(max(1, topK))) : sorted

        // Nucleus (top-p) accumulation
        let p = min(max(topP, 0.0), 1.0)
        var total = 0.0
        var nucleus: [(index: Int, prob: Double)] = []
        for (idx, prob) in kFiltered {
            total += prob
            nucleus.append((idx, prob))
            if total >= p { break }
        }
        if nucleus.isEmpty, let fallback = kFiltered.first {
            return fallback.offset
        }

        // Normalize within the nucleus
        let norm = nucleus.map { $0.prob }.reduce(0, +)
        if norm <= 0, let fallback = nucleus.first {
            return fallback.index
        }
        let normalized = nucleus.map { ($0.index, $0.prob / norm) }

        // Sample from the normalized nucleus
        let rand = Double.random(in: 0..<1)
        var acc = 0.0
        for (index, prob) in normalized {
            acc += prob
            if rand < acc { return index }
        }
        return normalized.last?.0 ?? 0
    }

    // Apply frequency and presence penalties in-place to logits.
    public func applyPenalties(
        logits: inout [Double],
        generatedTokens: [Int],
        frequencyPenalty: Double,
        presencePenalty: Double
    ) {
        guard (frequencyPenalty != 0) || (presencePenalty != 0), !generatedTokens.isEmpty else { return }

        // Count token occurrences
        var tokenCounts: [Int: Int] = [:]
        for token in generatedTokens {
            tokenCounts[token, default: 0] += 1
        }

        // Subtract penalties from logits safely
        for (token, count) in tokenCounts {
            guard token >= 0 && token < logits.count else { continue }
            if frequencyPenalty != 0 {
                logits[token] -= frequencyPenalty * Double(count)
            }
            if presencePenalty != 0 {
                logits[token] -= presencePenalty
            }
        }
    }
}
