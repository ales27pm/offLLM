export function cosineSimilarity(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return 0;
    }
    
    const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
    const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
    const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
    
    if (magnitudeA === 0 || magnitudeB === 0) {
        return 0;
    }
    
    return dotProduct / (magnitudeA * magnitudeB);
}

export function quantizeVector(vector, bits = 4) {
    if (!vector || vector.length === 0) return [];

    const maxVal = Math.max(...vector.map(Math.abs));
    if (maxVal === 0) {
        return new Array(vector.length).fill(0);
    }
    const scale = Math.pow(2, bits - 1) - 1;

    return vector.map(val => {
        const normalized = val / maxVal;
        return Math.round(normalized * scale);
    });
}

export function dequantizeVector(quantized, maxVal, bits = 4) {
    if (!quantized || quantized.length === 0) return [];
    if (typeof maxVal !== 'number' || maxVal === 0) return [];

    const scale = Math.pow(2, bits - 1) - 1;

    return quantized.map(qVal => {
        return (qVal / scale) * maxVal;
    });
}

export function normalizeVector(vector) {
    if (!vector || vector.length === 0) return [];
    
    const magnitude = Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
    
    if (magnitude === 0) return vector;
    
    return vector.map(val => val / magnitude);
}

export function euclideanDistance(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return Infinity;
    }
    
    return Math.sqrt(
        vecA.reduce((sum, a, i) => sum + Math.pow(a - vecB[i], 2), 0)
    );
}

export function manhattanDistance(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return Infinity;
    }
    
    return vecA.reduce((sum, a, i) => sum + Math.abs(a - vecB[i]), 0);
}

export function dotProduct(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return 0;
    }
    
    return vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
}

export function vectorMagnitude(vector) {
    if (!vector || vector.length === 0) {
        return 0;
    }
    
    return Math.sqrt(vector.reduce((sum, val) => sum + val * val, 0));
}

export function addVectors(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return [];
    }
    
    return vecA.map((a, i) => a + vecB[i]);
}

export function subtractVectors(vecA, vecB) {
    if (!vecA || !vecB || vecA.length !== vecB.length) {
        return [];
    }
    
    return vecA.map((a, i) => a - vecB[i]);
}

export function multiplyVectorByScalar(vector, scalar) {
    if (!vector || vector.length === 0) {
        return [];
    }
    
    return vector.map(val => val * scalar);
}

export function averageVectors(vectors) {
    if (!vectors || vectors.length === 0) {
        return [];
    }

    const dimension = vectors[0].length;
    if (!vectors.every(v => v.length === dimension)) {
        return [];
    }
    const result = new Array(dimension).fill(0);

    for (const vector of vectors) {
        for (let i = 0; i < dimension; i++) {
            result[i] += vector[i];
        }
    }

    return result.map(sum => sum / vectors.length);
}
