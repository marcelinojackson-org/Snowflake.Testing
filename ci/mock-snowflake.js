const path = require('path');
const Module = require('module');

const mockPath = path.join(__dirname, 'mocks', 'node_modules', 'snowflake-sdk');

const originalLoad = Module._load;
Module._load = function patchedLoad(request, parent, isMain) {
  if (request === 'snowflake-sdk') {
    return require(mockPath);
  }
  return originalLoad(request, parent, isMain);
};
