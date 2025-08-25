import SQLite from 'react-native-sqlite-storage';
import { cosineSimilarity, quantizeVector } from '../utils/vectorUtils';
import { Platform } from 'react-native';

const HNSW_DEFAULTS = {
    m: 16,
    efConstruction: 100,
    efSearch: 50,
    maxLayer: null,
    quantization: 'scalar'
};

export class ToolRegistry {
    constructor() {
        this.tools = new Map();
        this.toolCategories = new Map();
        this.executionHistory = [];
    }

    registerTool(toolName, toolDefinition, category = 'general') {
        if (!this.toolCategories.has(category)) {
            this.toolCategories.set(category, new Set());
        }
        
        this.tools.set(toolName, {
            ...toolDefinition,
            category,
            lastUsed: null,
            usageCount: 0
        });
        
        this.toolCategories.get(category).add(toolName);
    }

    async executeTool(toolName, parameters, context = {}) {
        const tool = this.tools.get(toolName);
        if (!tool) {
            throw new Error(`Tool ${toolName} not found`);
        }

        try {
            // Validate parameters
            this.validateParameters(tool, parameters);
            
            // Execute the tool
            const result = await tool.execute(parameters, context);
            
            // Update tool usage statistics
            tool.lastUsed = new Date();
            tool.usageCount = (tool.usageCount || 0) + 1;
            
            // Log execution
            this.executionHistory.push({
                tool: toolName,
                parameters,
                result,
                timestamp: new Date(),
                success: true
            });
            
            return result;
        } catch (error) {
            this.executionHistory.push({
                tool: toolName,
                parameters,
                error: error.message,
                timestamp: new Date(),
                success: false
            });
            
            throw error;
        }
    }

    validateParameters(tool, parameters) {
        if (tool.parameters) {
            for (const [paramName, paramConfig] of Object.entries(tool.parameters)) {
                if (paramConfig.required && !(paramName in parameters)) {
                    throw new Error(`Missing required parameter: ${paramName}`);
                }
                
                if (parameters[paramName] !== undefined && paramConfig.validate) {
                    if (!paramConfig.validate(parameters[paramName])) {
                        throw new Error(`Invalid value for parameter: ${paramName}`);
                    }
                }
            }
        }
    }

    getToolsByCategory(category) {
        return Array.from(this.toolCategories.get(category) || [])
            .map(toolName => this.tools.get(toolName));
    }

    getMostUsedTools(limit = 10) {
        return Array.from(this.tools.values())
            .sort((a, b) => (b.usageCount || 0) - (a.usageCount || 0))
            .slice(0, limit);
    }

    suggestTools(query, context) {
        // Simple tool suggestion based on name and description matching
        const queryLower = query.toLowerCase();
        
        return Array.from(this.tools.entries())
            .map(([name, tool]) => {
                let score = 0;
                
                // Name match
                if (name.toLowerCase().includes(queryLower)) {
                    score += 3;
                }
                
                // Description match
                if (tool.description && tool.description.toLowerCase().includes(queryLower)) {
                    score += 2;
                }
                
                // Category match
                if (tool.category && tool.category.toLowerCase().includes(queryLower)) {
                    score += 1;
                }
                
                // Recent usage bonus
                if (tool.lastUsed && (Date.now() - tool.lastUsed) < 24 * 60 * 60 * 1000) {
                    score += 0.5;
                }
                
                return { name, tool, score };
            })
            .filter(item => item.score > 0)
            .sort((a, b) => b.score - a.score)
            .map(item => item.name);
    }
}

export class MCPClient {
    constructor(serverUrl, options = {}) {
        this.serverUrl = serverUrl;
        this.options = {
            timeout: 30000,
            autoReconnect: true,
            reconnectDelay: 2000,
            maxReconnectAttempts: 5,
            ...options
        };
        this.connected = false;
        this.reconnectAttempts = 0;
        this.messageId = 0;
        this.pendingRequests = new Map();
        this.ws = null;
        this.messageQueue = [];
    }

    async connect() {
        return new Promise((resolve, reject) => {
            if (this.connected) {
                resolve();
                return;
            }

            try {
                this.ws = new WebSocket(this.serverUrl);
                
                this.ws.onopen = () => {
                    this.connected = true;
                    this.reconnectAttempts = 0;
                    console.log('MCP client connected to:', this.serverUrl);
                    
                    // Process any queued messages
                    this.processMessageQueue();
                    
                    resolve();
                };
                
                this.ws.onmessage = (event) => {
                    try {
                        const response = JSON.parse(event.data);
                        this.handleResponse(response);
                    } catch (error) {
                        console.error('Failed to parse MCP response:', error);
                    }
                };
                
                this.ws.onclose = (event) => {
                    this.connected = false;
                    console.log('MCP connection closed:', event.code, event.reason);
                    
                    if (this.options.autoReconnect && 
                        this.reconnectAttempts < this.options.maxReconnectAttempts) {
                        setTimeout(() => {
                            this.reconnectAttempts++;
                            console.log(`Reconnecting attempt ${this.reconnectAttempts}...`);
                            this.connect().catch(console.error);
                        }, this.options.reconnectDelay);
                    }
                };
                
                this.ws.onerror = (error) => {
                    console.error('MCP WebSocket error:', error);
                    reject(error);
                };
                
            } catch (error) {
                console.error('MCP connection failed:', error);
                reject(error);
            }
        });
    }

    async callTool(toolName, parameters) {
        if (!this.connected) {
            await this.connect();
        }

        const messageId = this.messageId++;
        const request = {
            jsonrpc: '2.0',
            id: messageId,
            method: 'tools/call',
            params: {
                name: toolName,
                arguments: parameters
            }
        };

        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                this.pendingRequests.delete(messageId);
                reject(new Error('MCP request timeout'));
            }, this.options.timeout);

            this.pendingRequests.set(messageId, { resolve, reject, timeout });
            
            this.sendRequest(request);
        });
    }

    async listTools() {
        if (!this.connected) {
            await this.connect();
        }

        const messageId = this.messageId++;
        const request = {
            jsonrpc: '2.0',
            id: messageId,
            method: 'tools/list'
        };

        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                this.pendingRequests.delete(messageId);
                reject(new Error('MCP request timeout'));
            }, this.options.timeout);

            this.pendingRequests.set(messageId, { resolve, reject, timeout });
            this.sendRequest(request);
        });
    }

    sendRequest(request) {
        if (this.connected && this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(request));
        } else {
            // Queue the message if not connected
            this.messageQueue.push(request);
            if (!this.connected) {
                this.connect().catch(console.error);
            }
        }
    }

    processMessageQueue() {
        while (this.messageQueue.length > 0 && this.connected) {
            const request = this.messageQueue.shift();
            this.ws.send(JSON.stringify(request));
        }
    }

    handleResponse(response) {
        const pending = this.pendingRequests.get(response.id);
        if (!pending) return;

        clearTimeout(pending.timeout);
        this.pendingRequests.delete(response.id);

        if (response.error) {
            pending.reject(new Error(response.error.message || 'MCP error'));
        } else {
            pending.resolve(response.result);
        }
    }

    disconnect() {
        this.options.autoReconnect = false;
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        this.connected = false;
        
        // Reject all pending requests
        for (const [id, pending] of this.pendingRequests) {
            clearTimeout(pending.timeout);
            pending.reject(new Error('MCP connection closed'));
        }
        this.pendingRequests.clear();
    }
}

// Example tool implementations

function evaluateExpression(expression) {
    const sanitized = expression.replace(/[^0-9+\-*/(). ]/g, '');
    const tokens = sanitized.match(/[+\-*/()]|[0-9]+(?:\.[0-9]+)?/g);
    if (!tokens) throw new Error('Invalid expression');
    const output = [];
    const ops = [];
    const precedence = { '+':1, '-':1, '*':2, '/':2 };
    for (const token of tokens) {
        if (/\d/.test(token)) {
            output.push(parseFloat(token));
        } else if (token in precedence) {
            while (ops.length && precedence[ops[ops.length-1]] >= precedence[token]) {
                output.push(ops.pop());
            }
            ops.push(token);
        } else if (token === '(') {
            ops.push(token);
        } else if (token === ')') {
            while (ops.length && ops[ops.length-1] !== '(') output.push(ops.pop());
            if (ops.pop() !== '(') throw new Error('Mismatched parentheses');
        }
    }
    while (ops.length) {
        const op = ops.pop();
        if (op === '(') throw new Error('Mismatched parentheses');
        output.push(op);
    }
    const stack = [];
    for (const token of output) {
        if (typeof token === 'number') stack.push(token);
        else {
            const b = stack.pop();
            const a = stack.pop();
            switch (token) {
                case '+': stack.push(a + b); break;
                case '-': stack.push(a - b); break;
                case '*': stack.push(a * b); break;
                case '/': stack.push(a / b); break;
            }
        }
    }
    if (stack.length !== 1) throw new Error('Invalid expression');
    return stack[0];
}

export const builtInTools = {
    calculator: {
        description: 'Perform mathematical calculations',
        parameters: {
            expression: {
                type: 'string',
                required: true,
                description: 'Mathematical expression to evaluate'
            }
        },
        execute: async (parameters) => {
            try {
                const result = evaluateExpression(parameters.expression);
                return { result, success: true };
            } catch (error) {
                return { error: error.message, success: false };
            }
        }
    },

    webSearch: {
        description: 'Search the web for information',
        parameters: {
            query: {
                type: 'string',
                required: true,
                description: 'Search query'
            },
            maxResults: {
                type: 'number',
                required: false,
                description: 'Maximum number of results to return',
                default: 5
            }
        },
        execute: async (parameters, context) => {
            // Implementation would depend on the search API
            // This is a placeholder implementation
            return {
                results: [
                    { title: 'Result 1', url: 'https://example.com/1', snippet: 'Snippet 1' },
                    { title: 'Result 2', url: 'https://example.com/2', snippet: 'Snippet 2' }
                ],
                success: true
            };
        }
    },

    fileSystem: {
        description: 'Read from and write to the file system',
        parameters: {
            operation: {
                type: 'string',
                required: true,
                enum: ['read', 'write', 'list'],
                description: 'File system operation to perform'
            },
            path: {
                type: 'string',
                required: true,
                description: 'File or directory path'
            },
            content: {
                type: 'string',
                required: false,
                description: 'Content to write (for write operations )'
            }
        },
        execute: async (parameters) => {
            // Implementation would use react-native-fs or similar
            // This is a placeholder implementation
            return { success: true, message: 'File operation completed' };
        }
    }
};
