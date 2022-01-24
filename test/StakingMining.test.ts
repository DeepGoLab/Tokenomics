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

// describe("StakingMining", function() {
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

//       // deploy voyagerStorage
//       const VoyagerStorage = await ethers.getContractFactory('VoyagerStorage', {
//         libraries: {"Sig": sig.address},
//       })
//       this.voyagerStorage = await VoyagerStorage.deploy(maxLevel);
//       console.log('voyagerStorage address is: '+this.voyagerStorage.address)

//       // deploy treasury
//       const Treasury = await ethers.getContractFactory('Treasury',{
//         libraries: {"Sig": sig.address},
//       })

//       this.treasury = await Treasury.deploy(this.dgtAddress,
//                                             this.voyagerStorage.address,
//                                             getBigNumber(4,17), 
//                                             this.startBlockNumber, 
//                                             this.startBlockNumber+this.continueBlocks);
//       console.log('treasury address is: '+this.treasury.address)
      
//       // deploy voyager
//       const Voyager = await ethers.getContractFactory("Voyager", {
//         libraries: {
//           Sig: sig.address,
//         },
//       });
//       const voyager = await Voyager.deploy(this.voyagerStorage.address);
//       this.voyager = await ethers.getContractAt('Voyager', 
//                                             voyager.address);
//       console.log('voyager address is: '+this.voyager.address)
      
//       this.tx = await this.voyagerStorage.setProxy(this.voyager.address)
//       await this.tx.wait()

//       this.tx = await this.voyager.setFee1TokenAddress(this.dgtAddress)
//       await this.tx.wait();
//       this.tx = await this.voyager.setFee2TokenAddress(this.dspAddress)
//       await this.tx.wait();
      
//       // deploy liquidityMining
//       const LiquidityMining = await ethers.getContractFactory('LiquidityMining',{
//         libraries: {"Sig": sig.address},
//       });
//       const liquidityMining = await LiquidityMining.deploy(this.treasury.address,
//                                                            this.voyagerStorage.address);
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

//       // 使用签名进行铸造: 
//       // 1. ip1 -> token#1 level 1
//       // 2. ip2 -> token#2 level 1
//       this.tx = await this.voyager.setToken0URI("token0URI")
//       await this.tx.wait()
//       console.log('token0URI set successfully')
//       this.signature = await sign(this.gp1.address, String(signer))
//       console.log('gp1 signature is: '+this.signature)

//       this.tx = await this.voyager.setWhitelistLevel(this.gp1.address, 1)
//       await this.tx.wait();
//       this.tx = await this.voyager.connect(this.gp1).mintVoyagerByWhitelist(this.signature)
//       await this.tx.wait();
//       console.log('token 0 nft minted')

//       this.signature = await sign(this.ip1.address, String(signer))
//       this.tx = await this.voyager.setWhitelistLevel(this.ip1.address, 1)
//       await this.tx.wait();
//       this.tx = await this.voyager.connect(this.ip1).mintVoyagerByWhitelist(this.signature)
//       await this.tx.wait();

//       this.tx = await this.voyager.setTokenURI(this.ip1.address, 1, 1, "token1URI")
//       console.log('ip1 first nft minted')

//       this.signature = await sign(this.ip2.address, String(signer))
//       this.tx = await this.voyager.setWhitelistLevel(this.ip2.address, 1)
//       await this.tx.wait();
//       this.tx = await this.voyager.connect(this.ip2).mintVoyagerByWhitelist(this.signature)
//       await this.tx.wait();
//       this.tx = await this.voyager.setTokenURI(this.ip2.address, 2, 1, "token2URI")
//       console.log('ip2 first nft minted')
      
//       expect(await this.voyagerStorage.balanceOf(this.ip1.address))
//         .to.be.equal(1)
//       expect(await this.voyagerStorage.balanceOf(this.ip2.address))
//         .to.be.equal(1)
//       console.log("ip1, ip2 NFT balance checked")

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
    
//     it ("create staking mining without staking NFT", async function() {
//       console.log("\n\n\n————————————————————1. create staking mining without staking NFT————————————————————\n")
//       // approve
//       this.tx = await this.dgt.connect(this.ip1).approve(
//                                this.liquidityMining.address,
//                                getBigNumber(100)
//                                );
//       await this.tx.wait()

//       this.tx = await this.liquidityMining.connect(this.ip1)
//                           .depositStaking(getBigNumber(100))
//       await this.tx.wait()

//       // after 10 block mined
//       for (let i=0; i<10000; i++){
//         this.tx = await ethers.provider.send("evm_mine", []);
//       }

//       // updatePool reward allocation
//       this.tx = await this.liquidityMining.updateStakingPool()
//       await this.tx.wait()
//       // check reward: about 0.2 * 100 = 20
//       this.reward = await this.treasury.getUserReward(0, this.ip1.address)
//       console.log('reward accumulated in 10000 block is: '+this.reward/this.ether) 

//       // withdraw half balance(50) is correct  
//       this.dgtBefore = await this.dgt.balanceOf(this.ip1.address)
//       console.log(this.dgtBefore/this.ether)
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                                         .withdrawStaking(getBigNumber(50))
//       await this.tx.wait()
//       this.dgtAfter = await this.dgt.balanceOf(this.ip1.address)
//       console.log(this.dgtAfter/this.ether)
//       console.log('DGT reward get is: '+this.dgtAfter.sub(this.dgtBefore)
//       .sub(getBigNumber(50)) / this.ether)
//     })

//     it("ip1 stake NFT token#1Level#1", async function() {
//       console.log("\n\n\n————————————————————2. ip1 stake NFT token#1Level#1————————————————————\n")
//       // approve NFT transfer
//       // [75, 100, 125, 150, 175, 200, 225]
//       this.tx = await this.voyagerStorage.connect(this.ip1).approve(
//           this.liquidityMining.address, 
//           1
//       )
//       // ip1 stake NFT
//       this.tx = await this.liquidityMining.connect(this.ip1).stakeNFT(1)
//       await this.tx.wait()
//       console.log('ip1 NFT staked')
//       // ip2 stake 100, now ip1:ip2 = 1:2
//       this.tx = await this.dgt.connect(this.ip2).approve(
//                               this.liquidityMining.address,
//                               getBigNumber(100)
//                               );
//       await this.tx.wait()
//       this.tx = await this.liquidityMining.connect(this.ip2)
//                           .depositStaking(getBigNumber(100))
//       await this.tx.wait()
//       // after 100 block mined
//       for (let i=0; i<10000; i++){
//         this.tx = await ethers.provider.send("evm_mine", []);
//       }
//       this.dgt2Before = await this.dgt.balanceOf(this.ip2.address)
//       // ip1 withdraw 25 is correct
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                                         .withdrawStaking(getBigNumber(25))
//       await this.tx.wait()
//       // ip2 withdraw 0
//       this.tx = await this.liquidityMining.connect(this.ip2)
//                           .withdrawStaking(getBigNumber(0))
//       await this.tx.wait()
//       this.dgtAfter2 = await this.dgt.balanceOf(this.ip1.address)
//       this.dgt2After = await this.dgt.balanceOf(this.ip2.address)
//       // reward ratio of ip1 and ip2 = (1 / 2) * (100 / 75) = 2 : 3
//       console.log('ip1 DGT reward get is: '+this.dgtAfter2.sub(this.dgtAfter)
//                                             .sub(getBigNumber(25)) / this.ether)
//       console.log('ip2 DGT reward get is: '+this.dgt2After.sub(this.dgt2Before)
//                                              / this.ether)    
//     })

//     it ("3. ip1 unstake, ip2 stake NFT token#2Level#1", async function() {
//       console.log('ip1 staked tokenId'+(await this.treasury.stakeTokenId(this.ip1.address)))
//       // ip1 unstake NFT
//       this.tx = await this.liquidityMining.connect(this.ip1).unstakeNFT()
//       await this.tx.wait()
//       console.log('Unstake ip1 NFT finished')
//       // ip2 stake NFT
//       this.tx = await this.voyagerStorage.connect(this.ip2).approve(
//         this.liquidityMining.address, 
//         2
//       )
//       // ip2 stake NFT
//       this.tx = await this.liquidityMining.connect(this.ip2).stakeNFT(2)
//       await this.tx.wait()
//       console.log('ip2 NFT staked')      
//       // after 10000 block mined
//       for (let i=0; i<10000; i++){
//         this.tx = await ethers.provider.send("evm_mine", []);
//       }   
//       // ip1 withdraw 0 
//       this.tx = await this.liquidityMining.connect(this.ip1)
//                                           .withdrawStaking(getBigNumber(0))
//       await this.tx.wait()
//       // ip2 withdraw 0
//       this.tx = await this.liquidityMining.connect(this.ip2)
//                                           .withdrawStaking(getBigNumber(0))
//       await this.tx.wait()
//       this.dgtAfter3 = await this.dgt.balanceOf(this.ip1.address)
//       this.dgt2After2 = await this.dgt.balanceOf(this.ip2.address)
//       // reward ratio of ip1 and ip2 = （1 / 4） * （75 / 100）= 3:16
//       console.log('ip1 DGT reward get is: '+this.dgtAfter3.sub(this.dgtAfter2)
//                       / this.ether)
//       console.log('ip2 DGT reward get is: '+this.dgt2After2.sub(this.dgt2After)
//                       / this.ether)  
//     })
// })