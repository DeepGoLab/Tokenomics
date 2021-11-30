// require('dotenv').config();

// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Signer } from "ethers";
// import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign, toHex} from "./utils"
// import { text } from "stream/consumers";
// import { isCommunityResourcable } from "@ethersproject/providers";
// const { time } = require("@openzeppelin/test-helpers")
// // this.now = await time.latest()
// // await time.increaseTo(this.now.add(time.duration.seconds(24*3601)))
// const Web3 = require('web3');
// const signer = process.env.OWNER_PRIVATE_KEY
// const weights = [75, 100, 125, 150, 175, 200, 225]
// const maxLevel = 6;
// // todo：设置升级费用
// // const levelUpFee = [10,100,20,200,30,300,40,400,50,500,60,600];
// console.log("————————————————————0. deploy configuration————————————————————\n")
// console.log('signer is:'+signer)

// describe("LiquidityMining", function() {
//     before(async function() {
//       this.ether = 1e18
//       this.dgtAddress = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE";
//       this.dspAddress = "0x9E4a6f10EdB8A69080ec10a173E3b0DFE167479E"; // TT4
      
//       this.web3 = new Web3(
//           // add websocket from infura
//           new Web3.providers.HttpProvider("http://localhost:8546") 
//       );
  
//       this.signers = await ethers.getSigners();
//       this.ip1 = this.signers[1];
//       this.ip2 = this.signers[2];
//       this.gp1 = this.signers[3];  
//       console.log(await sign(this.gp1.address, String(signer)))

//       this.startBlockNumber = await this.web3.eth.getBlockNumber()
//       this.continueBlocks = 1250000 
//       console.log('startBlockNumber is: '+this.startBlockNumber)
  
//       this.dgt = await ethers.getContractAt('IERC20', this.dgtAddress);
//       this.dsp = await ethers.getContractAt('IERC20', this.dspAddress);

//       const Sig = await ethers.getContractFactory("Sig");
//       const sig = await Sig.deploy();

//       // deploy treasury
//       const Treasury = await ethers.getContractFactory('Treasury',{
//         libraries: {"Sig": sig.address},
//       })
//       console.log('Treasury deployed')
//       this.treasury = await Treasury.deploy(this.dgtAddress,
//                                             sig.address,
//                                             getBigNumber(4,17), 
//                                             this.startBlockNumber, 
//                                             this.startBlockNumber+this.continueBlocks);
//       console.log('treasury address is: '+this.treasury.address)

//       // deploy liquidityMining
//       const LiquidityMining = await ethers.getContractFactory('LiquidityMining',{
//         libraries: {"Sig": sig.address},
//       });
//       const liquidityMining = await LiquidityMining.deploy(this.treasury.address,
//                                                             sig.address);
//       this.liquidityMining = await  ethers.getContractAt('LiquidityMining', liquidityMining.address)
//       console.log("Liquidity Mining address: " + liquidityMining.address)

//       this.tx = await this.treasury.setProxy(this.liquidityMining.address)
//       await this.tx.wait()
      
//       // 设置每个等级的staking挖矿权重
//       for (let i=0; i<7; i++) {
//         this.tx = await this.treasury.setWeightOfLevel(i, weights[i])
//         await this.tx.wait()
//       }
//       console.log("staking weight set")

//       // save DGT to treasury
//       this.tx = await this.dgt.connect(this.ip1).transfer(this.treasury.address, getBigNumber(10000))

//       // create staking pool: 
//       // 1. 分配权重1
//       // 2. 质押代币DGT
//       // 3. 费率0
//       // 4. 更新权重
//       this.tx = await this.liquidityMining.add(1, this.dgtAddress, 0, true)
//       await this.tx.wait()
//       console.log('staking pool created')

//       // create lq pool
//       this.tx = await this.liquidityMining.add(1, this.dspAddress, 0, true)
//       await this.tx.wait()
//       console.log('liquidity mining pool created')
//     })
    
//     it ("ip1 create liquidity mining", async function() {
//       console.log("\n\n\n————————————————————1. create liquidity mining————————————————————\n")
//       // approve
//       this.tx = await this.dsp.connect(this.ip1).approve(
//                                this.liquidityMining.address,
//                                getBigNumber(100)
//                                );
//       await this.tx.wait()
//      // deposit 100 dsp
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                           .deposit(1, getBigNumber(100))
//       await this.tx.wait()
//       console.log('dsp staked')
//       // after 10 block mined
//       for (let i=0; i<10000; i++){
//         this.tx = await ethers.provider.send("evm_mine", []);
//       }

//       // updatePool reward allocation
//       this.tx = await this.liquidityMining.updatePool(1)
//       await this.tx.wait()
//       console.log('update pool')
//       // check reward: about 0.2 * 100 = 20
//       this.reward = await this.treasury.getUserReward(1, this.ip1.address)
//       console.log('reward accumulated in 100 block is: '+this.reward/this.ether) 
//       //////// debug start 
//       console.log('multiplier is: '+(await this.treasury.getMultiplier(
//         (await this.treasury.getLastRewardBlock(1)).toNumber(),
//         await this.web3.eth.getBlockNumber()
//       ))) // 3
//       console.log('每个block的奖励: '+(await this.treasury.getDGTPerBlock()) / this.ether) // 0.4
//       console.log('SingleAllocPoint is: '+(await this.treasury.getSingleAllocPoint(1))) // 1
//       console.log('TotalAllocPoint is: '+(await this.treasury.getTotalAllocPoint())) // 2
//       // dgt reward = 3(block数量) * 0.4 * 1 / 2 (pool每个区块分到的DGT)
//       // AccDGTPerShare += dgt reward / 7500
//       console.log('AccDGTPerShare is: '+(await this.treasury.getAccDGTPerShare(1)))  // 
//       console.log('totalStakeShare is: '+(await this.treasury.totalStakeShare())/this.ether) // 7500
//       //////// debug end

//       // withdraw half balance(50) is correct  
//       this.dspBefore = await this.dsp.balanceOf(this.ip1.address)
//       this.dgtBefore = await this.dgt.balanceOf(this.ip1.address)
//       console.log(this.dgtBefore/this.ether)
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                                         .withdraw(1, getBigNumber(50))
//       await this.tx.wait()
//       console.log('withdraw success')
//       this.dgtAfter = await this.dgt.balanceOf(this.ip1.address)
//       this.dspAfter = await this.dsp.balanceOf(this.ip1.address)
//       console.log(this.dgtAfter/this.ether)
//       console.log('DGT reward get is: '+this.dgtAfter.sub(this.dgtBefore)
//                                                       / this.ether)
//       console.log('DSP withdrawed is: '+this.dspAfter.sub(this.dspBefore)
//                                                       / this.ether)
//     })

//     it("ip2 add liquidity", async function() {
//       console.log("\n\n\n————————————————————2. ip2 add liquidity————————————————————\n")
//       // ip2 stake 100, now ip1:ip2 = 1:2
//       this.tx = await this.dsp.connect(this.ip2).approve(
//                               this.liquidityMining.address,
//                               getBigNumber(100)
//                               );
//       await this.tx.wait()
//       this.tx = await this.liquidityMining.connect(this.ip2)
//                           .deposit(1, getBigNumber(100))
//       await this.tx.wait()
//       // after 100 block mined
//       for (let i=0; i<10000; i++){
//         this.tx = await ethers.provider.send("evm_mine", []);
//       }
//       this.dgt2Before = await this.dgt.balanceOf(this.ip2.address)
//       // ip1 withdraw 25 is correct
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                                         .withdraw(1, getBigNumber(25))
//       await this.tx.wait()
//       // ip2 withdraw 0
//       this.tx = await this.liquidityMining.connect(this.ip2)
//                           .withdraw(1, getBigNumber(0))
//       await this.tx.wait()
//       this.dgtAfter2 = await this.dgt.balanceOf(this.ip1.address)
//       this.dgt2After = await this.dgt.balanceOf(this.ip2.address)
//       // reward ratio of ip1 and ip2 = 1 / 2
//       console.log('ip1 DGT reward get is: '+this.dgtAfter2.sub(this.dgtAfter)
//                                              / this.ether)
//       console.log('ip2 DGT reward get is: '+this.dgt2After.sub(this.dgt2Before)
//                                              / this.ether)    
//     })

//     // it ("3. ip1 unstake, ip2 stake NFT token#2Level#1", async function() {
//     //   console.log('ip1 staked tokenId'+(await this.treasury.stakeTokenId(this.ip1.address)))
//     //   // ip1 unstake NFT
//     //   this.tx = await this.liquidityMining.connect(this.ip1).unstakeNFT()
//     //   await this.tx.wait()
//     //   console.log('Unstake ip1 NFT finished')
//     //   // ip2 stake NFT
//     //   this.tx = await this.voyagerStorage.connect(this.ip2).approve(
//     //     this.liquidityMining.address, 
//     //     2
//     //   )
//     //   // ip2 stake NFT
//     //   this.tx = await this.liquidityMining.connect(this.ip2).stakeNFT(2)
//     //   await this.tx.wait()
//     //   console.log('ip2 NFT staked')      
//     //   // after 10000 block mined
//     //   for (let i=0; i<10000; i++){
//     //     this.tx = await ethers.provider.send("evm_mine", []);
//     //   }   
//     //   // ip1 withdraw 0 
//     //   this.tx = await this.liquidityMining.connect(this.ip1)
//     //                                       .withdrawStaking(getBigNumber(0))
//     //   await this.tx.wait()
//     //   // ip2 withdraw 0
//     //   this.tx = await this.liquidityMining.connect(this.ip2)
//     //                                       .withdrawStaking(getBigNumber(0))
//     //   await this.tx.wait()
//     //   this.dgtAfter3 = await this.dgt.balanceOf(this.ip1.address)
//     //   this.dgt2After2 = await this.dgt.balanceOf(this.ip2.address)
//     //   // reward ratio of ip1 and ip2 = （1 / 4） * （75 / 100）= 3:16
//     //   console.log('ip1 DGT reward get is: '+this.dgtAfter3.sub(this.dgtAfter2)
//     //                   / this.ether)
//     //   console.log('ip2 DGT reward get is: '+this.dgt2After2.sub(this.dgt2After)
//     //                   / this.ether)  
//     // })
// })
//     //   //////// debug start 
//     //   console.log('multiplier is: '+(await this.treasury.getMultiplier(
//     //     (await this.treasury.getLastRewardBlock(0)).toNumber(),
//     //     await this.web3.eth.getBlockNumber()
//     //   ))) // 3
//     //   console.log('每个block的奖励: '+(await this.treasury.getDGTPerBlock()) / this.ether) // 0.4
//     //   console.log('SingleAllocPoint is: '+(await this.treasury.getSingleAllocPoint(0))) // 1
//     //   console.log('TotalAllocPoint is: '+(await this.treasury.getTotalAllocPoint())) // 2
//     //   // dgt reward = 3(block数量) * 0.4 * 1 / 2 (pool每个区块分到的DGT)
//     //   // AccDGTPerShare += dgt reward / 7500
//     //   console.log('AccDGTPerShare is: '+(await this.treasury.getAccDGTPerShare(0)))  // 
//     //   console.log('totalStakeShare is: '+(await this.treasury.totalStakeShare())/this.ether) // 7500
//     //   //////// debug end

//       // //////// test stake and unstake start
//       // // ip1 stake NFT
//       // this.tx = await this.voyagerStorage.connect(this.ip1).approve(
//       //   this.liquidityMining.address, 
//       //   1
//       // )
//       // // ip2 stake NFT
//       // this.tx = await this.liquidityMining.connect(this.ip1).stakeNFT(1)
//       // await this.tx.wait()
//       // console.log('ip1 NFT staked')   
//       // console.log(await this.treasury.stakeTokenId(this.ip1.address))
//       // // ip1 unstake NFT
//       // this.tx = await this.liquidityMining.connect(this.ip1).unstakeNFT()
//       // await this.tx.wait()
//       // console.log('Unstake ip1 NFT finished')
//       // ///////// test stake and unstake finished  