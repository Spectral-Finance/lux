// Rebuild with solc@0.8.30: set NODE_PATH to the node_modules directory containing
// solc and run: node test/fixtures/web3/compile.cjs
const fs = require("node:fs");
const path = require("node:path");
const solc = require("solc");
const source = fs.readFileSync(path.join(__dirname, "Transactions.sol"), "utf8");
const input = {
  language: "Solidity",
  sources: { "Transactions.sol": { content: source } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: "cancun",
    outputSelection: { "*": { "*": ["evm.bytecode.object"] } }
  }
};
const output = JSON.parse(solc.compile(JSON.stringify(input)));
const errors = (output.errors || []).filter(e => e.severity === "error");
if (errors.length) throw new Error(errors.map(e => e.formattedMessage).join("\n"));
const fixtures = { compiler: solc.version() };
for (const [name, contract] of Object.entries(output.contracts["Transactions.sol"])) {
  fixtures[name] = "0x" + contract.evm.bytecode.object;
}
fs.writeFileSync(path.join(__dirname, "transactions.json"), JSON.stringify(fixtures, null, 2) + "\n");
