// require('dotenv').config();

// import { expect } from "chai";
// import { ethers } from "hardhat";
// import { Signer } from "ethers";
// import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign} from "./utils"
// import { text } from "stream/consumers";

// const signer = process.env.OWNER_PRIVATE_KEY
// console.log('signer is:'+signer)

// describe("DeepSeaPlankton", function() {
//   before(async function() {
//     this.signers = await ethers.getSigners();
//     this.ip1 = this.signers[1];
//     this.ip2 = this.signers[2];
//     this.gp1 = this.signers[3];

//     const DeepSeaPlankton = await ethers.getContractFactory("DeepSeaPlankton");
//     const dsp = await DeepSeaPlankton.deploy();
//     this.dsp = await ethers.getContractAt('DeepSeaPlankton', dsp.address);

//     console.log('DeepSeaPlankton address: '+ dsp.address)

//     // minter是owner， add gp1 to minters
//     this.tx = await this.dsp.addMinters([this.gp1.address])
//     await this.tx.wait()
//   })

//   it ("mint token", async function() {
//     // mint by Minters
//     this.tx = await this.dsp.connect(this.gp1).mintByMinter(this.ip1.address, getBigNumber(100))
//     await this.tx.wait()
//     // mint by Users
//     this.tx = await this.dsp.addMintable(this.ip1.address, getBigNumber(9427))
//     await this.tx.wait()
//     this.tx = await this.dsp.connect(this.ip1).mintByUser()
//     await this.tx.wait()

//     // check balance 
//     expect(await this.dsp.balanceOf(this.ip1.address))
//       .to.be.equal(getBigNumber(9527))
//   })

//   it("transfer token", async function() {
//     this.tx = await this.dsp.connect(this.ip1).transfer(this.ip2.address, getBigNumber(1000))
//     await this.tx.wait()

//     // check balance 
//     expect(await this.dsp.balanceOf(this.ip1.address))
//       .to.be.equal(getBigNumber(8527))
//     expect(await this.dsp.balanceOf(this.ip2.address))
//       .to.be.equal(getBigNumber(1000))
//   })

//   it("burn token", async function() {
//     this.tx = await this.dsp.connect(this.ip1).burn(getBigNumber(8527))
//     await this.tx.wait()

//     // check balance 
//     expect(await this.dsp.balanceOf(this.ip1.address))
//       .to.be.equal(getBigNumber(0))
//   })

// })
