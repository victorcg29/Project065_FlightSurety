var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
// var mnemonic = "copy put expand enter transfer evoke express dial speak enroll phrase exhaust";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 4999999
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};