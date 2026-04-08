require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    // Local development
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    // Optimism Mainnet
    optimism: {
      url: process.env.OPTIMISM_RPC_URL || "https://mainnet.optimism.io",
      accounts: process.env.DEPLOYER_PRIVATE_KEY
        ? [process.env.DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 10,
    },
    // Optimism Sepolia Testnet
    "optimism-sepolia": {
      url:
        process.env.OPTIMISM_SEPOLIA_RPC_URL ||
        "https://sepolia.optimism.io",
      accounts: process.env.DEPLOYER_PRIVATE_KEY
        ? [process.env.DEPLOYER_PRIVATE_KEY]
        : [],
      chainId: 11155420,
    },
  },
  etherscan: {
    // Used for source-code verification on Etherscan / Optimistic-Etherscan
    apiKey: {
      optimisticEthereum: process.env.OPTIMISM_ETHERSCAN_API_KEY || "",
      optimismSepolia: process.env.OPTIMISM_ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "optimismSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimism.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io",
        },
      },
    ],
  },
};
