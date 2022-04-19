import * as dotenv from "dotenv";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "@nomiclabs/hardhat-ganache";

dotenv.config();

const key: any = process.env.PRIVATE_KEY;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  networks: {
    hardhat: {},
    localhost: {
      url: "http://localhost:8545",
    },
    ganache: {
      url: "http://localhost:8545",
    },
    mainnet: {
      url: process.env.MAINNET || "",
      accounts: [key],
    },
    harmony: {
      url: process.env.HARMONY || "",
      accounts: [key],
    },
    fantom: {
      url: process.env.FANTOM || "",
      accounts: [key],
    },
    avax: {
      url: process.env.AVAX || "",
      accounts: [key],
    },
    bsc: {
      url: process.env.BSC || "",
      accounts: [key],
    },
    cronos: {
      url: process.env.CRONOS || "",
      accounts: [key],
    },
    moonriver: {
      url: process.env.MOONRIVER || "",
      accounts: [key],
    },
    celo: {
      url: process.env.CELO || "",
      accounts: [key],
    },
    near: {
      url: process.env.NEAR || "",
      accounts: [key],
    },
    arbitrum: {
      url: process.env.ARBITRUM || "",
      accounts: [key],
    },
    polygon: {
      url: process.env.POLYGON || "",
      accounts: [key],
    },
    rinkeby: {
      url: process.env.RINKEBY || "",
      accounts: [key],
    },
    ropsten: {
      url: process.env.ROPSTEN || "",
      accounts: [key],
    },
    goerli: {
      url: process.env.GOERLI || "",
      accounts: [key],
    },
    kovan: {
      url: process.env.KOVAN || "",
      accounts: [key],
    },
    harmony_testnet: {
      url: process.env.HARMONY_TESTNET || "",
      accounts: [key],
    },
    bsc_testnet: {
      url: process.env.BSC_TESTNET || "",
      accounts: [key],
    },
    fuji: {
      url: process.env.FUJI || "",
      accounts: [key],
    },
    ftm_testnet: {
      url: process.env.FTM_TESTNET || "",
      accounts: [key],
    },
    mumbai: {
      url: process.env.MUMBAI || "",
      accounts: [key],
    },
  },
  gasReporter: {
    currency: "USD",
    token: "ETH",
    gasPrice: 60,
    //gasPriceApi: process.env.ETHERSCAN_API_KEY || "",
    coinmarketcap: process.env.COINMARKETCAP_KEY || "",
  },
  etherscan: {
    apiKey: {
      rinkeby: process.env.ETHERSCAN_API_KEY || "",
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      polygon: process.env.POLYGON_API_KEY || "",
    },
  },
};

export default config;
