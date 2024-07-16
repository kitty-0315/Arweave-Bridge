import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config();

const private_key = process.env.WALLET_PHARSE || "";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    ethereum: {
      url: 'https://rpc.sepolia.org',
      accounts: [private_key]
    }
  }
};

export default config;
