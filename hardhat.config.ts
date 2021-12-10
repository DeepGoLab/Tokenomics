import * as dotenv from "dotenv";
import "./task/operation.js"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-ethers"
import "@tenderly/hardhat-tenderly"
import "dotenv/config"
import "hardhat-deploy"
import "hardhat-contract-sizer"
import "@nomiclabs/hardhat-etherscan"
// import "./task/operation.js"

import { HardhatUserConfig } from "hardhat/types"

const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk",
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  defaultNetwork: "localhost",
  networks: {
    hardhat: {
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      gasPrice: 120 * 1000000000,
      chainId: 1,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 3,
      gasPrice: 5000000000,
      gasMultiplier: 2,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [`${process.env.OWNER_PRIVATE_KEY}`,
        `${process.env.IP1_PRIVATE_KEY}`,
        `${process.env.IP2_PRIVATE_KEY}`,
        `${process.env.GP1_PRIVATE_KEY}`,
        `${process.env.GP2_PRIVATE_KEY}`,
        `${process.env.LP1_PRIVATE_KEY}`,
        `${process.env.LP2_PRIVATE_KEY}`],
      chainId: 4,
      gas: 12450000,
      gasPrice: 8000000000,
      gasMultiplier: 2,
    },
    localhost: {
      url: "http://localhost:8546",
      chainId: 1337,
      gas: 12450000,
      gasPrice: 8000000000,
      gasMultiplier: 2,
      timeout: 100000,
    }
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "deploy",
    deployments: "deployments",
    imports: "imports",
    sources: "contracts",
    tests: "test",
  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  // networks: {
  //   ropsten: {
  //     url: process.env.ROPSTEN_URL || "",
  //     accounts:
  //       process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
  //   },
  // },
  // gasReporter: {
  //   enabled: process.env.REPORT_GAS !== undefined,
  //   currency: "USD",
  // },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 18000000
  },
  tenderly : {
    username: 'DeepGo',
    project: 'Tokenomics'
  }
};

export default config;
