require('dotenv').config();

import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign} from "./utils"
import { text } from "stream/consumers";
const Web3 = require('web3');

const signer = process.env.OWNER_PRIVATE_KEY
console.log('signer is:'+signer)

describe("DeepSeaPlankton", function() {
  before(async function() {
    this.signers = await ethers.getSigners();
    this.ip1 = this.signers[1];
    this.ip2 = this.signers[2];
    this.gp1 = this.signers[3];
    // console.log("gp1 address is: " + this.gp1.address)
    var web3 = new Web3(this.ip1, "http://localhost:8546");

    // using MultiOwned address as owner of dsp contract
    const MultiOwned = await ethers.getContractFactory("MultiOwned");
    const multiOwned = await MultiOwned.deploy(
        [this.ip1.address, this.ip2.address, this.gp1.address],
        2
    ); 
    console.log('multiOwned address: ' + multiOwned.address)
    const DeepSeaPlankton = await ethers.getContractFactory("DeepSeaPlankton");
    const dsp = await DeepSeaPlankton.deploy();
    this.dsp = await ethers.getContractAt('DeepSeaPlankton', dsp.address);
    
    // transfer ownership to MultiOwned
    this.tx = await this.dsp.transferOwnership(multiOwned.address)
    await this.tx.wait()
    console.log("ownership transferred")

    // rinkeby test: AF, IP1, DeepGoOwner
    //["0xcB71f617411D587A0b56fa56bfBa793Dd2F0303C","0x22354885Cec345A9D84494Af729e76F2784d79b6","0x6993AffA5572139D896B67Fe3A108B51EB6f8B53"]
    // execute transaction by MultiOwned
    this.tx = await this.ip1.sendTransaction({
        to: multiOwned.address,
        value: ethers.utils.parseEther("1.0"), // Sends exactly 1.0 ether
      });
    await this.tx.wait()

    var calldata = DeepSeaPlankton.interface.encodeFunctionData("addMinters",
        [[this.gp1.address]]
    )

    this.tx = await multiOwned.connect(this.ip1).submitTransaction(
        this.dsp.address, 
        0, 
        calldata,
        "text1")
    await this.tx.wait()

    var txId = await multiOwned.getTxId("text1")
    console.log('Tx id is: ' + txId)
    let minters = await this.dsp.getMinters()
    console.log(minters)
    this.tx = await multiOwned.connect(this.ip2).confirmTransaction(0)
    await this.tx.wait()
    // this.tx = await multiOwned.connect(this.gp1).confirmTransaction(parseInt(txId))
    // await this.tx.wait()
    minters = await this.dsp.getMinters()
    console.log(minters)
    console.log("Tx confirmed by all three")
    console.log("Multisig transaction confirmed and execute!")
    // // minter是owner， add gp1 to minters
    // this.tx = await this.dsp.addMinters([this.gp1.address])
    // await this.tx.wait()
    // console.log("addMinters finished")
  })

  it ("mint token", async function() {
    // mint by Minters
    this.tx = await this.dsp.connect(this.gp1).mintByMinter(this.ip1.address, getBigNumber(100))
    await this.tx.wait()
    // mint by Users
    this.tx = await this.dsp.addMintable(this.ip1.address, getBigNumber(9427))
    await this.tx.wait()
    this.tx = await this.dsp.connect(this.ip1).mintByUser()
    await this.tx.wait()

    // check balance 
    expect(await this.dsp.balanceOf(this.ip1.address))
      .to.be.equal(getBigNumber(9527))
  })

  it("transfer token", async function() {
    this.tx = await this.dsp.connect(this.ip1).transfer(this.ip2.address, getBigNumber(1000))
    await this.tx.wait()

    // check balance 
    expect(await this.dsp.balanceOf(this.ip1.address))
      .to.be.equal(getBigNumber(8527))
    expect(await this.dsp.balanceOf(this.ip2.address))
      .to.be.equal(getBigNumber(1000))
  })

  it("burn token", async function() {
    this.tx = await this.dsp.connect(this.ip1).burn(getBigNumber(8527))
    await this.tx.wait()

    // check balance 
    expect(await this.dsp.balanceOf(this.ip1.address))
      .to.be.equal(getBigNumber(0))
  })

})
