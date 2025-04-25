require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config({path:__dirname + '/.env'});

const {API_URL, PRIVATE_KEY} = process.env;
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true, 
      optimizer: {
        enabled: true,
        details: {
          yulDetails: {
            optimizerSteps: "u",
          }
        }
      }
    }
  },
    networks: {
      hedera_testnet: {
        url: API_URL, 
        accounts: [`${PRIVATE_KEY}`]
    }
  }
}
