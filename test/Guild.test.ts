require('dotenv').config();

import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign} from "./utils/index"

const { time } = require("@openzeppelin/test-helpers")
const signer = process.env.OWNER_PRIVATE_KEY
console.log('signer is:'+signer)

describe("Guild", function() {
  before(async function() {
    this.dsp = "0x9E4a6f10EdB8A69080ec10a173E3b0DFE167479E"; // TT4
    this.dgt = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE";
    this.DGT = await ethers.getContractAt('IERC20', this.dgt);
    this.DSP = await ethers.getContractAt('IERC20', this.dsp);
    console.log("dgt address: " + this.DGT.address);
    // this.dsp = "0x9E4a6f10EdB8A69080ec10a173E3b0DFE167479E"; // TT4

    this.signers = await ethers.getSigners();
    this.ip1 = this.signers[1];
    this.ip2 = this.signers[2];
    this.gp1 = this.signers[3];

    // deploy 
    const Sig = await ethers.getContractFactory("Sig");
    const sig = await Sig.deploy();
    const VoyagerStorage = await ethers.getContractFactory("VoyagerStorage", {
        libraries: {
          Sig: sig.address,
        },
      });

    this.voyagerStorage = await VoyagerStorage.deploy();
    const PilotStorage = await ethers.getContractFactory("PilotStorage", {
        libraries: {
          Sig: sig.address,
        },
      });
    this.pilotStorage = await PilotStorage.deploy();   
    const TreasuryStorage = await ethers.getContractFactory("TreasuryStorage", {
        libraries: {
          Sig: sig.address,
        },
      });
    this.treasuryStorage = await TreasuryStorage.deploy(
        this.pilotStorage.address, this.voyagerStorage.address
    );
    const PilotWhale = await ethers.getContractFactory("PilotWhale", {
        libraries: {
          Sig: sig.address,
        },
      });
    this.pilotWhale = await PilotWhale.deploy(
        this.pilotStorage.address, 
        this.voyagerStorage.address,
        this.treasuryStorage.address
    );  
    await this.pilotStorage.setProxy(this.pilotWhale.address)
    await this.voyagerStorage.setProxy(this.pilotWhale.address)
    await this.treasuryStorage.setProxy(this.pilotWhale.address)
    console.log("delpoy successfully")

    await this.pilotStorage.setDgtAddress(this.dgt)
    await this.pilotStorage.setDspAddress(this.dsp)
    await this.pilotStorage.setLevelUpExp(1, 0)
  })

  it("Mint Pilot#1", async function() {
    // mint first Pilot NFT by whitelist
    this.tx = await this.pilotWhale.setToken0URI("token0URI", true)
    await this.tx.wait()
    this.signature = await sign(this.ip1.address, String(signer))
    this.tx = await this.pilotWhale.connect(this.ip1).mintPilotByWhitelist(
        this.signature, "not for use", 0, 0, 0)
    await this.tx.wait();
    console.log('mint pilot#0 successfully')

    // mint second Pilot NFT by wwhitelist
    this.signature = await sign(this.ip2.address, String(signer))
    this.tx = await this.pilotWhale.connect(this.ip2).mintPilotByWhitelist(
        this.signature, "Pilot1", 5000, 1, 1)
    await this.tx.wait();
    console.log('mint pilot#1 successfully')
    let tokenId = (await this.pilotStorage.getMintTokenIDWithoutURI(this.ip2.address)).toNumber()
    console.log('tokenId:'+tokenId)
    await this.pilotWhale.setTokenURI(this.ip2.address, 1, "token#1", true)
    await this.tx.wait()
    })

    it("Mint Voyager#1", async function() {
      // mint first Voyager NFT by whitelist
      this.voyagerDGTFee = await this.voyagerStorage.baseMintFee()
      console.log('voyagerDGTFee is: '+this.voyagerDGTFee)
      this.tx = await this.DGT.connect(this.ip1).approve(
        this.pilotWhale.address, this.voyagerDGTFee);
      this.tx = await this.pilotWhale.setToken0URI("token0URI", false)
      await this.tx.wait()
      console.log('Voyager#0 set uri successfully')
      this.tx = await this.pilotWhale.connect(this.ip1).mintVoyager(0,0)
      await this.tx.wait();
      console.log('mint voyager#0 successfully')
  
      // mint second Voyager NFT by ip1
      this.tx = await this.DGT.connect(this.ip1).approve(
        this.pilotWhale.address, this.voyagerDGTFee);
      this.tx = await this.DSP.connect(this.ip1).approve(
        this.pilotWhale.address, getBigNumber(1*1**2 + 1));
      await this.tx.wait()
      console.log('voyager#1 approve successfully')
      console.log(await this.voyagerStorage.getTotalMinted())
      this.tx = await this.pilotWhale.connect(this.ip1).mintVoyager(1, 1)
      await this.tx.wait();
      console.log('mint voyager#1 successfully')
      await this.pilotWhale.setTokenURI(this.ip1.address, 1, "token#1", false)
      console.log('voyager#1 token uri set successfully')

      // mint third Voyager NFT by gp1
      this.tx = await this.DGT.connect(this.gp1).approve(
        this.pilotWhale.address, this.voyagerDGTFee);
      this.tx = await this.DSP.connect(this.gp1).approve(
        this.pilotWhale.address, getBigNumber(1*2**2 + 1));
      await this.tx.wait()
      console.log('voyager#2 approve successfully')
      console.log(await this.voyagerStorage.getTotalMinted())
      this.tx = await this.pilotWhale.connect(this.gp1).mintVoyager(1, 1)
      await this.tx.wait();
      console.log('mint voyager#2 successfully')
      await this.pilotWhale.setTokenURI(this.gp1.address, 1, "token#2", false)
      console.log('voyager#2 token uri set successfully')      
      })

      it("Level Up", async function() {
        this.levelUpFee = await this.voyagerStorage.levelUpFee()
        await this.tx.wait()
        this.tx = await this.DGT.connect(this.gp1).approve(
          this.pilotWhale.address, this.levelUpFee);
        this.tx = await this.pilotWhale.connect(this.gp1).levelUpByVoyager(1)
        await this.tx.wait()
      })

      // it("ClaimMoneyLess3Days", async function() {
      //   this.tx = await this.pilotWhale.connect(this.gp1).reedemVoyager(1)
      // })

      // it("ClaimMoneyOver3Days", async function() {

      // })

      // it("repay", async function() {

      // })

})
