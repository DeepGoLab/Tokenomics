// import { ethers } from "hardhat"
require('dotenv').config();
const { BigNumber } = require("ethers")
const Web3 = require('web3')

// represent connection to blockchain
const web3 = new Web3(
  // add websocket from infura
  new Web3.providers.HttpProvider(`https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`) 
);
const { address: admin } = web3.eth.accounts.wallet.add(process.env.OWNER_PRIVATE_KEY)
console.log(admin)

export const BASE_TEN = 10
export const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

export function toHex(amount: number, privateKey: String) {
  let { address: signer } = web3.eth.accounts.wallet.add(privateKey)
  return web3.utils.numberToHex(amount)
}

// Defaults to e18 using amount * 10^18
export function getBigNumber(amount: number, decimals = 18) {
  return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals))
}

export function numToBigNumber(amount: number, decimals = 18) {
  return getBigNumber(Math.floor(amount / 10 ** decimals), decimals)
}

export function getDGTAddress(chainId: String) {
  var DGT = ""
  if (chainId === '1') {
    // mainnet
    DGT = "0xc8eec1277b84fc8a79364d0add8c256b795c6727"

  } else if (chainId === '3') {
      // ropsten
      DGT = "0x689a4FBAD3c022270caBD1dbE2C7e482474a70bc"
      // DGTBenifit = deployer

  } else if (chainId === '4') {
      // rinkeby
      DGT = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE"
      // DGTBenifit = deployer
  } else if (chainId === '1337') {
      DGT = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE"
  } else if (chainId === '56') {
      DGT = ""
  }
  return DGT
}

export async function sign2(addr: string, privateKey: string) {
  let { address: signer } = web3.eth.accounts.wallet.add(privateKey)
  var hashMessage = web3.utils.soliditySha3(addr)
//   // "0x4bc82ecb914143406301ebaca8a5d68d43b2074d2472a36b9cea56bdce8b013b"
  var signature = await web3.eth.sign(hashMessage, signer);    // sign the random hash or the ethHash
  signature = signature.substr(0, 130) + (signature.substr(130) == "00" ? "1b" : "1c");
  // console.log('hashMessage: '+hashMessage)
  // console.log('eth.sign: '+signature)
  return signature
}

export async function sign(addr: string, privateKey: string) {
    var hashMessage = web3.utils.soliditySha3(addr)
    var sig = await web3.eth.accounts.sign( hashMessage, privateKey )
    return sig.signature
  

//   var sig2 = await web3.eth.accounts.sign( "0x16e0ff39086bb50b49c5654fc1041e7d185bf0786434d27019c3b147bb8b1c11", process.env.POLYGON_OWNER_PRIVATE_KEY )
//   console.log('eth.account: '+sig2.signature)

//   const results = await dgVerify
//   .methods
//   .totalSupply()
//   .call();

//   console.log(results)
// }{
//   return new Promise((resolve) => {
//     setTimeout(() => {
//       resolve('');
//     }, ms)
//   });
}

const testFunc = async () => {
  const Ip1Address = "0x22354885Cec345A9D84494Af729e76F2784d79b6";
  console.log(await sign(Ip1Address, admin))
}

// testFunc()

module.exports = {
  BASE_TEN: BASE_TEN,
  ADDRESS_ZERO: ADDRESS_ZERO,
  getBigNumber: getBigNumber,
  numToBigNumber: numToBigNumber,
  sign: sign,
  getDGTAddress: getDGTAddress
}
