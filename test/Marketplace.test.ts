// require('dotenv').config();

// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Signer } from "ethers";
// import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign, toHex} from "./utils"
// import { text } from "stream/consumers";

// const Web3 = require('web3');
// const signer = process.env.OWNER_PRIVATE_KEY
// console.log('signer is:'+signer)

// // 测试币：dgt，注意输入数值Big Number
// describe("Marketplace", function() {
//   before(async function() {
//     this.dgt = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE";
    
//     this.web3 = new Web3(
//         // add websocket from infura
//         new Web3.providers.HttpProvider("http://localhost:8546") 
//     );

//     this.signers = await ethers.getSigners();
//     this.ip1 = this.signers[1];
//     this.ip2 = this.signers[2];
//     this.gp1 = this.signers[3];  

//     this.DGT = await ethers.getContractAt('IERC20', this.dgt);

//     const Nft = await ethers.getContractFactory("NFT");
//     const nft = await Nft.deploy();
//     this.nft = await ethers.getContractAt('NFT', nft.address)
//     console.log("NFT address: " + nft.address)

//     const Sig = await ethers.getContractFactory("Sig");
//     const sig = await Sig.deploy();

//     const Marketplace = await ethers.getContractFactory("Marketplace",{
//         libraries: {"Sig": sig.address},
//     });
//     const marketplace = await Marketplace.deploy();
//     this.marketplace = await ethers.getContractAt('Marketplace', marketplace.address);
//     console.log("Marketplace address: " + marketplace.address)

//     // add quoteToken 
//     this.tx = await this.marketplace.addQuoteTokens([this.dgt])
//     await this.tx.wait()
//     console.log("quote token added")

//     // mint NFT
//     this.tx = await this.nft.connect(this.ip1).mint() 
//     await this.tx.wait()
//     this.tx = await this.nft.connect(this.ip2).mint() 
//     await this.tx.wait()
    
//     expect(await this.nft.balanceOf(this.ip1.address))
//       .to.be.equal(1)
//     expect(await this.nft.balanceOf(this.ip2.address))
//       .to.be.equal(1)
//   })
  
//   it ("Place order by ETH", async function() {
//     // ip1 token#0  
//     this.tx = await this.nft.connect(this.ip1).approve(this.marketplace.address, 0)
//     await this.tx.wait()
//     this.tx = await this.marketplace.connect(this.ip1).createMarketItemByBNB(
//         this.nft.address,
//         0,
//         getBigNumber(10)
//     )
//     await this.tx.wait()
//     console.log("Market Item Created")

//     expect(await this.nft.balanceOf(this.ip1.address))
//       .to.be.equal(0)
    
//     this.tx = await this.marketplace.connect(this.ip1).cancelMarketSale(
//         1
//     )
//     await this.tx.wait()
//   })

// //   it ("Place order by DGT", async function() {
// //     // ip2 token#1
// //     this.tx = await this.nft.connect(this.ip2).approve(this.marketplace.address, 1)
// //     await this.tx.wait()
// //     this.tx = await this.marketplace.connect(this.ip2).createMarketItem(
// //         this.nft.address,
// //         this.dgt,
// //         1,
// //         getBigNumber(100)
// //     )
// //     await this.tx.wait()

// //     expect(await this.nft.balanceOf(this.ip2.address))
// //       .to.be.equal(0)
// //   })

// //   it ("check all items on sale", async function() {
// //     // tokenID#0 and #1 on sale
// //     this.items = await this.marketplace.fetchUnsoldItems()
// //     // check #0 value
// //     console.log(this.items)
// //   })

// //   it ("ip1 buy item#2-token#1", async function() {
// //     var ip1BalanceBefore = await this.DGT.balanceOf(this.ip1.address)
// //     this.price = await this.marketplace.getPrice(2)

// //     this.tx = await this.DGT.connect(this.ip1).approve(
// //         this.marketplace.address, 
// //         this.price
// //     )
// //     await this.tx.wait()

// //     this.tx = await this.marketplace.connect(this.ip1).createMarketSale(
// //         this.nft.address,
// //         2
// //     )
// //     await this.tx.wait()

// //     var ip1BalanceAfter = await this.DGT.balanceOf(this.ip1.address)

// //     expect(await this.nft.balanceOf(this.ip1.address))
// //      .to.be.equal(1)
// //     expect(ip1BalanceBefore.sub(ip1BalanceAfter))
// //       .to.be.equal(this.price)

// //     this.items = await this.marketplace.fetchUnsoldItems()
// //     console.log(this.items)
// //   })

// // //   it ("ip2 buy item#1-token#0", async function() {
// // //     this.price = await this.marketplace.getPrice(1)
// // //     this.price = this.price.toString()
// // //     this.price = this.price.substr(0, this.price.length-18)
// // //     console.log('token 2 ether price:'+this.price)

// // //     this.tx = await this.marketplace.connect(this.ip2).createMarketSale(
// // //         this.nft.address,
// // //         1,
// // //         {
// // //             value: ethers.utils.parseEther(this.price) 
// // //         }
// // //     )
// // //     await this.tx.wait()
// // //     // this.balance = await this.provider.getBalance(this.ip2.address);

// // //     this.balance = await this.web3.eth.getBalance(this.ip2.address)
// // //     console.log('ip2 ether balance: ' + this.balance)

// // //     expect(await this.nft.balanceOf(this.ip2.address))
// // //       .to.be.equal(1)
    
// // //     this.items = await this.marketplace.fetchUnsoldItems()
// // //     console.log(this.items)
// // //   })  

// //   it ("transfer by owner item#1-token#0", async function() {
// //     this.tx = await this.marketplace.withdrawNFT(this.nft.address, 
// //                                                  this.ip1.address,
// //                                                  getBigNumber(0))
// //     await this.tx.wait()
// //     expect(await this.nft.balanceOf(this.ip1.address))
// //                          .to.be.equal(2)
// //   })
// })
