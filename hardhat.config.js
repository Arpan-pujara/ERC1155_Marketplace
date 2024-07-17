require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('@nomicfoundation/hardhat-ethers');
require('dotenv').config();
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.12',
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    // mumbai: {
    //   url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.GORELI_ALCHEMY_KEY}`,
    //   accounts: [process.env.PRIVATE_KEY],
    // },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.SEPOLIA_ALCHEMY_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.MAINNET_ALCHEMY_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
    amoy: {
      url: `https://polygon-amoy.g.alchemy.com/v2/${process.env.AMOY_ALCHEMY_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  // gasReporter: {
  //   enabled: true,
  //   currency: 'INR',
  //   coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  //   token: "ETH"
  // },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
    disambiguatePaths: false,
    strict: true,
    except: [],
  },
};
