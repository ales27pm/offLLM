const plugins = new Map();
const hooks = new Map();
const originals = new Map();

export class PluginManager {
    constructor() {
        this.plugins = new Map();
        this.activePlugins = new Set();
        this.hooks = new Map();
        this.originals = new Map();
        this.overrides = new Map();
    }

    registerPlugin(name, plugin) {
        this.plugins.set(name, {
            ...plugin,
            enabled: false
        });
        
        if (plugin.hooks) {
            for (const [hookName, hookFunction] of Object.entries(plugin.hooks)) {
                this.registerHook(hookName, hookFunction);
            }
        }
    }

    async enablePlugin(name) {
        if (!this.plugins.has(name)) {
            throw new Error(`Plugin ${name} not registered`);
        }
        
        const plugin = this.plugins.get(name);
        
        try {
            if (plugin.initialize) {
                await plugin.initialize();
            }
            
            if (plugin.replace) {
                for (const [target, implementation] of Object.entries(plugin.replace)) {
                    this._replaceModuleFunction(target, implementation);
                }
            }
            
            if (plugin.extend) {
                for (const [target, extensions] of Object.entries(plugin.extend)) {
                    this._extendModule(target, extensions);
                }
            }
            
            plugin.enabled = true;
            this.activePlugins.add(name);
            
            console.log(`Plugin ${name} enabled successfully`);
        } catch (error) {
            console.error(`Failed to enable plugin ${name}:`, error);
            throw error;
        }
    }

    async disablePlugin(name) {
        if (!this.plugins.has(name) || !this.plugins.get(name).enabled) {
            return;
        }
        
        const plugin = this.plugins.get(name);
        
        try {
            if (plugin.cleanup) {
                await plugin.cleanup();
            }
            
            if (plugin.replace) {
                for (const [target] of Object.entries(plugin.replace)) {
                    this._restoreModuleFunction(target);
                }
            }
            
            if (plugin.extend) {
                for (const [target, extensions] of Object.entries(plugin.extend)) {
                    this._removeModuleExtensions(target, Object.keys(extensions));
                }
            }
            
            plugin.enabled = false;
            this.activePlugins.delete(name);
            
            console.log(`Plugin ${name} disabled successfully`);
        } catch (error) {
            console.error(`Failed to disable plugin ${name}:`, error);
        }
    }

    registerHook(hookName, hookFunction) {
        if (!this.hooks.has(hookName)) {
            this.hooks.set(hookName, []);
        }
        
        this.hooks.get(hookName).push(hookFunction);
    }

    async executeHook(hookName, ...args) {
        if (!this.hooks.has(hookName)) {
            return;
        }
        
        const results = [];
        for (const hookFunction of this.hooks.get(hookName)) {
            try {
                results.push(await hookFunction(...args));
            } catch (error) {
                console.error(`Error executing hook ${hookName}:`, error);
            }
        }
        
        return results;
    }

    async execute(methodName, args, context) {
        const results = await this.executeHook(`before_${methodName}`, ...args);
        
        let result;
        if (this.hasOverride(methodName)) {
            result = await this._executeOverride(methodName, args, context);
        } else {
            if (context[methodName]) {
                result = await context[methodName](...args);
            } else {
                throw new Error(`Method ${methodName} not found`);
            }
        }
        
        await this.executeHook(`after_${methodName}`, result, ...args);
        
        return result;
    }

    hasOverride(methodName) {
        for (const plugin of this.plugins.values()) {
            if (plugin.replace && plugin.replace[methodName]) {
                return true;
            }
        }
        return false;
    }

    isPluginEnabled(name) {
        return this.plugins.has(name) && this.plugins.get(name).enabled;
    }

    _replaceModuleFunction(modulePath, implementation) {
        if (!this.overrides) {
            this.overrides = new Map();
        }
        if (!this.originals.has(modulePath)) {
            const parts = modulePath.split('.');
            const moduleName = parts[0];
            const functionName = parts[1];
            this.originals.set(modulePath, global[moduleName][functionName]);
        }
        this.overrides.set(modulePath, implementation);
    }

    getModuleFunction(modulePath) {
        if (this.overrides && this.overrides.has(modulePath)) {
            return this.overrides.get(modulePath);
        }
        if (this.originals.has(modulePath)) {
            return this.originals.get(modulePath);
        }
        const parts = modulePath.split('.');
        const moduleName = parts[0];
        const functionName = parts[1];
        return global[moduleName][functionName];
    }

    _restoreModuleFunction(modulePath) {
        if (this.originals.has(modulePath)) {
            const parts = modulePath.split('.');
            const moduleName = parts[0];
            const functionName = parts[1];
            
            global[moduleName][functionName] = this.originals.get(modulePath);
            this.originals.delete(modulePath);
        }
    }

    _extendModule(moduleName, extensions) {
        if (!global[moduleName]) {
            global[moduleName] = {};
        }
        
        for (const [key, value] of Object.entries(extensions)) {
            const fullPath = `${moduleName}.${key}`;
            if (!this.originals.has(fullPath) && global[moduleName][key] !== undefined) {
                this.originals.set(fullPath, global[moduleName][key]);
            }
            
            global[moduleName][key] = value;
        }
    }

    _removeModuleExtensions(moduleName, keys) {
        for (const key of keys) {
            const fullPath = `${moduleName}.${key}`;
            if (this.originals.has(fullPath)) {
                global[moduleName][key] = this.originals.get(fullPath);
                this.originals.delete(fullPath);
            } else {
                delete global[moduleName][key];
            }
        }
    }

    _executeOverride(methodName, args, context) {
        for (const plugin of this.plugins.values()) {
            if (plugin.replace && plugin.replace[methodName]) {
                return plugin.replace[methodName].apply(context, args);
            }
        }
        
        throw new Error(`Override for ${methodName} not found`);
    }
}
