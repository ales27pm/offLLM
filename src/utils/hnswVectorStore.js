import SQLite from 'react-native-sqlite-storage';
import { cosineSimilarity, quantizeVector } from './vectorUtils';

const HNSW_DEFAULTS = {
    m: 16,
    efConstruction: 100,
    efSearch: 50,
    maxLayer: null,
    quantization: 'scalar'
};

export class HNSWVectorStore {
    constructor() {
        this.db = null;
        this.initialized = false;
        this.index = {
            layers: [],
            entryPoint: null,
            maxLayer: 0
        };
        this.config = { ...HNSW_DEFAULTS };
        this.nodeMap = new Map();
    }

    async initialize(config = {}) {
        if (this.initialized) return;
        
        this.config = { ...this.config, ...config };
        
        try {
            this.db = await SQLite.openDatabase({
                name: 'hnsw_vectorstore.db',
                location: 'default',
                createFromLocation: 1
            });
            
            await this.db.executeSql('PRAGMA foreign_keys = ON;');
            
            await this._createTables();
            await this._loadIndex();
            
            this.initialized = true;
            console.log('HNSW Vector Store initialized');
        } catch (error) {
            console.error('Failed to initialize HNSW Vector Store:', error);
            throw error;
        }
    }

    async _createTables() {
        await this.db.executeSql(`
            CREATE TABLE IF NOT EXISTS vectors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                metadata TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        
        await this.db.executeSql(`
            CREATE TABLE IF NOT EXISTS vector_data (
                id INTEGER PRIMARY KEY,
                vector BLOB NOT NULL,
                quantized BLOB,
                FOREIGN KEY (id) REFERENCES vectors (id) ON DELETE CASCADE
            )
        `);
        
        await this.db.executeSql(`
            CREATE TABLE IF NOT EXISTS hnsw_layers (
                layer INTEGER NOT NULL,
                node_id INTEGER NOT NULL,
                connections TEXT NOT NULL,
                PRIMARY KEY (layer, node_id)
            )
        `);
        
        await this.db.executeSql(`
            CREATE TABLE IF NOT EXISTS hnsw_config (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        `);
        
        await this.db.executeSql(`
            CREATE INDEX IF NOT EXISTS idx_hnsw_layers_node 
            ON hnsw_layers (node_id)
        `);
    }

    async _loadIndex() {
        const [configResults] = await this.db.executeSql(
            'SELECT * FROM hnsw_config'
        );
        
        const configRows = configResults.rows.raw();
        configRows.forEach(row => {
            if (row.key === 'entryPoint') {
                this.index.entryPoint = parseInt(row.value);
            } else if (row.key === 'maxLayer') {
                this.index.maxLayer = parseInt(row.value);
                this.config.maxLayer = this.index.maxLayer;
            } else {
                this.config[row.key] = JSON.parse(row.value);
            }
        });
        
        this.index.layers = new Array(this.index.maxLayer + 1).fill().map(() => new Map());
        
        const [layerResults] = await this.db.executeSql(
            'SELECT * FROM hnsw_layers ORDER BY layer'
        );
        
        layerResults.rows.raw().forEach(row => {
            const layer = parseInt(row.layer);
            const node_id = parseInt(row.node_id);
            const connections = JSON.parse(row.connections);
            
            if (!this.index.layers[layer]) {
                this.index.layers[layer] = new Map();
            }
            
            this.index.layers[layer].set(node_id, connections);
        });
        
        if (this.nodeMap.size === 0) {
            await this._loadNodeMap();
        }
    }

    async _loadNodeMap() {
        const [vectorResults] = await this.db.executeSql(`
            SELECT v.id, v.content, v.metadata, vd.vector 
            FROM vectors v 
            JOIN vector_data vd ON v.id = vd.id
        `);
        
        vectorResults.rows.raw().forEach(row => {
            const blob = new Uint8Array(row.vector);
            const vector = new Float32Array(blob.buffer);
            this.nodeMap.set(row.id, {
                content: row.content,
                metadata: JSON.parse(row.metadata || '{}'),
                vector: Array.from(vector)
            });
        });
    }

    async addVector(content, vector, metadata = {}) {
        if (!this.initialized) await this.initialize();
        
        try {
            const [result] = await this.db.executeSql(
                'INSERT INTO vectors (content, metadata) VALUES (?, ?)',
                [content, JSON.stringify(metadata)]
            );
            const id = result.insertId;
            
            const quantizedVector = this._quantizeVector(vector);
            
            const buffer = new ArrayBuffer(vector.length * 4);
            const view = new Float32Array(buffer);
            vector.forEach((v, i) => view[i] = v);
            
            let quantizedBlob = null;
            if (quantizedVector) {
                const quantizedBuffer = new ArrayBuffer(quantizedVector.length);
                const quantizedView = new Uint8Array(quantizedBuffer);
                quantizedVector.forEach((v, i) => quantizedView[i] = v);
                quantizedBlob = quantizedView;
            }
            
            await this.db.executeSql(
                'INSERT INTO vector_data (id, vector, quantized) VALUES (?, ?, ?)',
                [id, new Uint8Array(buffer), quantizedBlob]
            );
            
            await this._addToIndex(id, vector);
            
            return id;
        } catch (error) {
            console.error('Failed to add vector to HNSW:', error);
            throw error;
        }
    }

    _quantizeVector(vector) {
        if (this.config.quantization === 'none') return null;
        
        if (this.config.quantization === 'scalar') {
            return quantizeVector(vector);
        }
        
        return null;
    }

    async _addToIndex(id, vector) {
        const layer = this._getRandomLayer();
        
        if (this.index.entryPoint === null) {
            this.index.entryPoint = id;
            this.index.maxLayer = layer;
            this.config.maxLayer = this.index.maxLayer;
            
            await this._saveConfig();
            return;
        }
        
        let currNode = this.index.entryPoint;
        let currLayer = Math.min(this.index.maxLayer, layer);
        
        while (currLayer > layer) {
            currNode = await this._searchLayer(vector, currNode, currLayer, 1);
            currLayer--;
        }
        
        for (let l = Math.min(layer, this.index.maxLayer); l >= 0; l--) {
            const neighbors = await this._searchLayer(vector, currNode, l, this.config.efConstruction);
            await this._insertNodeAtLayer(id, vector, l, neighbors);
            
            if (l === this.index.maxLayer && neighbors.length > 0) {
                this.index.maxLayer = l + 1;
                this.config.maxLayer = this.index.maxLayer;
                await this._saveConfig();
            }
        }
    }

    _getRandomLayer() {
        return Math.min(
            Math.floor(-Math.log(Math.random()) * Math.log(this.config.m)),
            this.config.maxLayer || 16
        );
    }

    async _searchLayer(queryVector, enterPoint, layer, ef) {
        const visited = new Set();
        const candidates = new PriorityQueue((a, b) => 
            cosineSimilarity(queryVector, this.nodeMap.get(a).vector) > 
            cosineSimilarity(queryVector, this.nodeMap.get(b).vector)
        );
        const results = new PriorityQueue((a, b) => 
            cosineSimilarity(queryVector, this.nodeMap.get(a).vector) > 
            cosineSimilarity(queryVector, this.nodeMap.get(b).vector)
        );
        
        visited.add(enterPoint);
        candidates.add(enterPoint);
        results.add(enterPoint);
        
        while (candidates.size() > 0) {
            const current = candidates.poll();
            const currentVector = this.nodeMap.get(current).vector;
            const currentSimilarity = cosineSimilarity(queryVector, currentVector);
            
            if (results.size() >= ef && currentSimilarity < results.peekPriority()) {
                break;
            }
            
            const connections = this.index.layers[layer].get(current) || [];
            
            for (const neighborId of connections) {
                if (!visited.has(neighborId)) {
                    visited.add(neighborId);
                    const neighborVector = this.nodeMap.get(neighborId).vector;
                    const neighborSimilarity = cosineSimilarity(queryVector, neighborVector);
                    
                    candidates.add(neighborId, neighborSimilarity);
                    
                    if (results.size() < ef || neighborSimilarity > results.peekPriority()) {
                        results.add(neighborId, neighborSimilarity);
                        if (results.size() > ef) {
                            results.poll();
                        }
                    }
                }
            }
        }
        
        return results.toArray().map(item => item.value);
    }

    async _insertNodeAtLayer(nodeId, vector, layer, neighbors) {
        if (!this.index.layers[layer]) {
            this.index.layers[layer] = new Map();
        }
        
        this.index.layers[layer].set(nodeId, [...neighbors]);
        
        for (const neighborId of neighbors) {
            const neighborConnections = this.index.layers[layer].get(neighborId) || [];
            neighborConnections.push(nodeId);
            
            if (neighborConnections.length > this.config.m) {
                const trimmed = await this._searchLayer(
                    this.nodeMap.get(neighborId).vector,
                    neighborId,
                    layer,
                    this.config.m
                );
                this.index.layers[layer].set(neighborId, trimmed);
            } else {
                this.index.layers[layer].set(neighborId, neighborConnections);
            }
        }
        
        await this.db.executeSql(
            'INSERT OR REPLACE INTO hnsw_layers (layer, node_id, connections) VALUES (?, ?, ?)',
            [layer, nodeId, JSON.stringify(neighbors)]
        );
    }

    async searchVectors(queryVector, limit = 5) {
        if (!this.initialized) await this.initialize();
        
        try {
            let currNode = this.index.entryPoint;
            let currLayer = this.index.maxLayer;
            
            while (currLayer >= 0) {
                currNode = await this._searchLayer(
                    queryVector, 
                    currNode, 
                    currLayer, 
                    this.config.efSearch
                )[0] || currNode;
                currLayer--;
            }
            
            const results = await this._searchLayer(
                queryVector, 
                currNode, 
                0, 
                Math.max(this.config.efSearch, limit * 2)
            );
            
            const detailedResults = [];
            for (const id of results.slice(0, limit * 2)) {
                const node = this.nodeMap.get(id);
                if (node) {
                    const similarity = cosineSimilarity(queryVector, node.vector);
                    detailedResults.push({
                        id,
                        content: node.content,
                        metadata: node.metadata,
                        similarity
                    });
                }
            }
            
            return detailedResults
                .sort((a, b) => b.similarity - a.similarity)
                .slice(0, limit);
        } catch (error) {
            console.error('HNSW search failed:', error);
            return this._fallbackSearch(queryVector, limit);
        }
    }

    async _fallbackSearch(queryVector, limit = 5) {
        const [results] = await this.db.executeSql(`
            SELECT v.id, v.content, v.metadata, vd.vector 
            FROM vectors v 
            JOIN vector_data vd ON v.id = vd.id 
            ORDER BY v.created_at DESC 
            LIMIT 1000
        `);
        
        const rows = results.rows.raw();
        const similarities = [];
        
        for (const row of rows) {
            const blob = new Uint8Array(row.vector);
            const storedVector = new Float32Array(blob.buffer);
            const similarity = cosineSimilarity(
                queryVector, 
                Array.from(storedVector)
            );
            
            similarities.push({
                id: row.id,
                content: row.content,
                metadata: JSON.parse(row.metadata || '{}'),
                similarity
            });
        }
        
        return similarities
            .sort((a, b) => b.similarity - a.similarity)
            .slice(0, limit);
    }

    async _saveConfig() {
        const operations = [
            this.db.executeSql(
                'INSERT OR REPLACE INTO hnsw_config (key, value) VALUES (?, ?)',
                ['entryPoint', this.index.entryPoint.toString()]
            ),
            this.db.executeSql(
                'INSERT OR REPLACE INTO hnsw_config (key, value) VALUES (?, ?)',
                ['maxLayer', this.index.maxLayer.toString()]
            ),
            this.db.executeSql(
                'INSERT OR REPLACE INTO hnsw_config (key, value) VALUES (?, ?)',
                ['m', JSON.stringify(this.config.m)]
            ),
            this.db.executeSql(
                'INSERT OR REPLACE INTO hnsw_config (key, value) VALUES (?, ?)',
                ['efConstruction', JSON.stringify(this.config.efConstruction)]
            ),
            this.db.executeSql(
                'INSERT OR REPLACE INTO hnsw_config (key, value) VALUES (?, ?)',
                ['efSearch', JSON.stringify(this.config.efSearch)]
            )
        ];
        
        await Promise.all(operations);
    }
    
    async clearVectors() {
        if (!this.initialized) await this.initialize();
        
        try {
            await this.db.executeSql('DELETE FROM vectors');
            await this.db.executeSql('DELETE FROM vector_data');
            await this.db.executeSql('DELETE FROM hnsw_layers');
            await this.db.executeSql('DELETE FROM hnsw_config');
            
            this.index = {
                layers: [],
                entryPoint: null,
                maxLayer: 0
            };
            this.nodeMap.clear();
            
            return true;
        } catch (error) {
            console.error('Failed to clear vectors:', error);
            return false;
        }
    }
    
    async getVectorCount() {
        if (!this.initialized) await this.initialize();
        
        try {
            const [results] = await this.db.executeSql('SELECT COUNT(*) as count FROM vectors');
            return results.rows.raw()[0].count;
        } catch (error) {
            console.error('Failed to get vector count:', error);
            return 0;
        }
    }
}

class PriorityQueue {
    constructor(comparator = (a, b) => a > b) {
        this._heap = [];
        this._comparator = comparator;
    }
    
    size() {
        return this._heap.length;
    }
    
    isEmpty() {
        return this.size() === 0;
    }
    
    peek() {
        return this._heap[0];
    }
    
    peekPriority() {
        return this._heap[0] ? this._heap[0].priority : -Infinity;
    }
    
    add(value, priority = 1) {
        this._heap.push({ value, priority });
        this._siftUp();
        return this;
    }
    
    poll() {
        const result = this.peek();
        const last = this._heap.pop();
        if (this.size() > 0) {
            this._heap[0] = last;
            this._siftDown();
        }
        return result;
    }
    
    toArray() {
        return [...this._heap];
    }
    
    _siftUp() {
        let nodeIdx = this.size() - 1;
        while (nodeIdx > 0 && this._compare(nodeIdx, this._parent(nodeIdx))) {
            this._swap(nodeIdx, this._parent(nodeIdx));
            nodeIdx = this._parent(nodeIdx);
        }
    }
    
    _siftDown() {
        let nodeIdx = 0;
        while (
            (this._left(nodeIdx) < this.size() && this._compare(this._left(nodeIdx), nodeIdx)) ||
            (this._right(nodeIdx) < this.size() && this._compare(this._right(nodeIdx), nodeIdx))
        ) {
            const greaterChild = 
                this._right(nodeIdx) < this.size() && 
                this._compare(this._right(nodeIdx), this._left(nodeIdx)) 
                    ? this._right(nodeIdx) 
                    : this._left(nodeIdx);
            this._swap(nodeIdx, greaterChild);
            nodeIdx = greaterChild;
        }
    }
    
    _compare(i, j) {
        return this._comparator(
            this._heap[i].priority, 
            this._heap[j].priority
        );
    }
    
    _swap(i, j) {
        [this._heap[i], this._heap[j]] = [this._heap[j], this._heap[i]];
    }
    
    _parent(i) {
        return (i - 1) >> 1;
    }
    
    _left(i) {
        return (i << 1) + 1;
    }
    
    _right(i) {
        return (i + 1) << 1;
    }
}
