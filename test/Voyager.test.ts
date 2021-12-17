require('dotenv').config();

import { expect } from "chai";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { BASE_TEN, ADDRESS_ZERO, getBigNumber, numToBigNumber, sign} from "./utils"
// import { time } from "console";
const { time } = require("@openzeppelin/test-helpers")

const maxLevel = 6;
const signer = process.env.OWNER_PRIVATE_KEY
console.log('signer is:'+signer)

describe("Voyager", function() {
  before(async function() {
    this.dgt = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE";
    this.DGT = await ethers.getContractAt('IERC20', this.dgt);
    console.log("dgt address: " + this.DGT.address);
    // this.dsp = "0x9E4a6f10EdB8A69080ec10a173E3b0DFE167479E"; // TT4

    this.signers = await ethers.getSigners();
    this.ip1 = this.signers[1];
    this.ip2 = this.signers[2];
    this.gp1 = this.signers[3];
    // deploy dsp
    const DeepSeaPlankton = await ethers.getContractFactory("DeepSeaPlankton");
    const dsp = await DeepSeaPlankton.deploy();
    this.DSP = await ethers.getContractAt('DeepSeaPlankton', dsp.address);
    this.dsp = this.DSP.address
    console.log("dsp address: " + this.DSP.address);
    // deploy sig
    const Sig = await ethers.getContractFactory("Sig");
    const sig = await Sig.deploy();

    const VoyagerStorage = await ethers.getContractFactory("VoyagerStorage", {
      libraries: {
        Sig: sig.address,
      },
    });
    const voyagerStorage = await VoyagerStorage.deploy(maxLevel);
    this._voyagerStorage = await ethers.getContractAt('VoyagerStorage', 
                                          voyagerStorage.address);
    console.log('VoyagerStorage address: '+ voyagerStorage.address)

    const Voyager = await ethers.getContractFactory("Voyager", {
      libraries: {
        Sig: sig.address,
      },
    });
    const voyager = await Voyager.deploy(voyagerStorage.address);
    this._voyager = await ethers.getContractAt('Voyager', 
                                          voyager.address);
    console.log('Voyager address: '+ voyager.address)

    this.tx = await voyagerStorage.setProxy(voyager.address)
    await this.tx.wait()

    this.tx = await voyager.setFee1TokenAddress(this.dgt)
    await this.tx.wait();
    this.tx = await voyager.setFee2TokenAddress(this.dsp)
    await this.tx.wait();
    console.log(await voyagerStorage.dgtAddress())
    console.log(await voyagerStorage.dspAddress())
  })

  // 对比NFT balance
  it("Mint first NFT by whitelist correct", async function() {
    // 使用签名进行铸造
    this.tx = await this._voyager.setToken0URI("token0URI")
    await this.tx.wait()

    console.log('ip1 signature is: '+(await sign(this.ip1.address, String(signer))))
    this.signature = await sign(this.ip1.address, String(signer))
    this.tx = await this._voyager.setWhitelistLevel(this.ip1.address, 6)
    await this.tx.wait();
    this.tx = await this._voyager.connect(this.ip1).mintVoyagerByWhitelist(this.signature)
    await this.tx.wait();
    console.log('ip1 mint successfully')
    
    // 铸造后ip1的balance为1
    expect(await this._voyagerStorage.balanceOf(this.ip1.address))
      .to.be.equal(1)

    // tokenID为0，level为6，tokenURI为：token0URI
    this.tokenId = await this._voyagerStorage.ownedVoyagers(this.ip1.address, 0)
    expect((await this._voyagerStorage.getVoyagerByTokenId(this.tokenId))[0])
      .to.be.equal(6)
    expect((await this._voyagerStorage.getVoyagerByTokenId(this.tokenId))[1])
      .to.be.equal(getBigNumber(0))
    expect((await this._voyagerStorage.tokenURI(0)))
      .to.be.equal("token0URI")
    
    // // todo: 打印用户持有时间及验证满足持有时间要求的最大等级
    // console.log('holding time is: '+(await this._voyagerStorage.ownedVoyagers(this.ip1.address, 0))[2])

    // token#0: ip1 holding time 1 day
    this.now = await time.latest()
    await time.increaseTo(this.now.add(time.duration.seconds(24*3601)))
    expect((await this._voyagerStorage.getValidMaxLevel(this.ip1.address,1)))
      .to.be.equal(6)

    // time.sleep(20)
    // var ip1Owned = await this._voyagerStorage.tokenIdsOwnedBy(this.ip1.address)
    // console.log('ip1 owned ids: ' + ip1Owned)
  })

  it("Mint second NFT by user correct", async function() {
    var mintFeeRes = await this._voyagerStorage.getMintFee()
    this.dgtMintFee = mintFeeRes[0]
    this.dspMintFee = mintFeeRes[1]
    // mint dsp for mint NFT
    this.tx = await this.DSP.mintByMinter(this.ip1.address, this.dspMintFee)
    await this.tx.wait()
    console.log('mint dsp for ip1')
    let dgtBefore = await this.DGT.balanceOf(this.ip1.address)
    let dspBefore = await this.DSP.balanceOf(this.ip1.address)
    console.log('get ip1 balance')
    // approve dgt cost for mint
    this.tx = await this.DGT.connect(this.ip1).approve(
                    this._voyager.address, 
                    this.dgtMintFee
                    );
    await this.tx.wait()
    console.log('ip1 approve dgt cost')
    // approve dgt cost for mint
    this.tx = await this.DSP.connect(this.ip1).approve(
                    this._voyager.address, 
                    this.dspMintFee
                    );
    await this.tx.wait()
    console.log('ip1 approve dsp cost')
    // mint NFT
    this.tx = await this._voyager.connect(this.ip1).mintVoyager()
    await this.tx.wait()
    console.log('ip1 mint nft')
    // 后端获取tokenID，level
    let tokenId = (await this._voyagerStorage.getTokenIDWithoutURI(this.ip1.address)).toNumber()
    if (tokenId == 0) {
        tokenId = (await this._voyagerStorage.getMintTokenIDWithoutURI(this.ip1.address)).toNumber()
    }
    console.log('tokenId is:'+tokenId)
    let tokenIndex = (await this._voyagerStorage.allVoyagersIndex(tokenId)).toNumber()
    console.log("tokenIndex is: "+tokenIndex)
    let level = (await this._voyagerStorage.voyagers(tokenIndex))[0]
    console.log("level is: "+level)
    // set NFT URI
    this.tx = await this._voyager.setTokenURI(this.ip1.address, tokenId,level,"token#1URILevel1")
    await this.tx.wait()
    console.log('set tokenURI')
    // dgt and dsp balance of ip1 after mint
    let dgtAfter = await this.DGT.balanceOf(this.ip1.address)
    let dspAfter = await this.DSP.balanceOf(this.ip1.address)
    // mint fee cost correctly
    expect(dgtBefore.sub(dgtAfter))
      .to.be.equal(this.dgtMintFee)
    expect(dspBefore.sub(dspAfter))
      .to.be.equal(this.dspMintFee)
    // dgt and dsp balance in Voyager contract 
    expect(await this.DGT.balanceOf(this._voyager.address))
      .to.be.equal(this.dgtMintFee)
    expect(await this.DSP.balanceOf(this._voyager.address))
      .to.be.equal(this.dspMintFee)
    // transfer dgt 
    this.tx = await this._voyager.withdrawDGT(this.dgtMintFee, this.ip1.address)
    await this.tx.wait()
    console.log('withdraw dgt mint fee revenue')
    // burn dsp
    this.tx = await this._voyager.burnDSP()
    await this.tx.wait()
    console.log('burn dsp')
    // dgt and dsp balance in voyager contract correctly
    expect(await this.DGT.balanceOf(this._voyager.address))
      .to.be.equal(getBigNumber(0))
    expect(await this.DSP.balanceOf(this._voyager.address))
      .to.be.equal(getBigNumber(0))
  })

// 测试在ip1 token#1当前等级持有天数：
// 1. 推移10天，check持有时间及当前等级持有时间
// 2. 升级，check升级成本
// 3. 推移10天，check持有时间及当前等级持有时间
// 4. 升级，check升级成本

  it("Level Up correct", async function() {
    // 推移10天
    this.now = await time.latest()
    await time.increaseTo(this.now.add(time.duration.seconds(10*24*3600+1)))
    // check持有时间及当前等级持有时间
    expect(await this._voyagerStorage.getHoldingDays(1))
      .to.be.equal(10)
    expect(await this._voyagerStorage.getCurLevelHoldingDays(1))
      .to.be.equal(10)
    // dgt and dsp fee for level1up
    this.levelUpFeeRes = await this._voyagerStorage.getLevelUpFeeV2(1)
    console.log(this.levelUpFeeRes)
    this.dgtLevelUpFee = this.levelUpFeeRes[0]
    this.dspLevelUpFee = this.levelUpFeeRes[1]
    // mint dsp for level1up
    this.tx = await this.DSP.mintByMinter(this.ip1.address, this.dspLevelUpFee)
    await this.tx.wait()
    // dgt and dsp balance of ip1 before level1 up
    let dgtBefore = await this.DGT.balanceOf(this.ip1.address)
    let dspBefore = await this.DSP.balanceOf(this.ip1.address)
    // approve token transfer before levelup
    this.tx = await this.DGT.connect(this.ip1).approve(
      this._voyager.address, this.dgtLevelUpFee);
    await this.tx.wait()
    this.tx = await this.DSP.connect(this.ip1).approve(
      this._voyager.address, this.dspLevelUpFee);
    await this.tx.wait()
    // ip1 held token to level up 
    this.tx = await this._voyager.connect(this.ip1).levelUp(1)
    await this.tx.wait()

    // dgt and dsp balance of ip1 after mint
    let dgtAfter = await this.DGT.balanceOf(this.ip1.address)
    let dspAfter = await this.DSP.balanceOf(this.ip1.address)
    // levelup1 fee cost correctly
    expect(dgtBefore.sub(dgtAfter))
      .to.be.equal(this.dgtLevelUpFee)
    expect(dspBefore.sub(dspAfter))
      .to.be.equal(this.dspLevelUpFee)

    // 后端获取tokenID，level
    let tokenId = (await this._voyagerStorage.getTokenIDWithoutURI(this.ip1.address)).toNumber()
    let tokenIndex = (await this._voyagerStorage.allVoyagersIndex(tokenId)).toNumber()
    let level = (await this._voyagerStorage.voyagers(tokenIndex))[0]
    // set NFT URI
    this.tx = await this._voyager.setTokenURI(this.ip1.address, tokenId, level, "token1URILevel2")
    await this.tx.wait()
    // check level 
    expect(level).to.be.equal(2)
    console.log('level1up finished')

    // 推移10天
    this.now = await time.latest()
    await time.increaseTo(this.now.add(time.duration.seconds(10*24*3600)))
    // check持有时间及当前等级持有时间
    expect(await this._voyagerStorage.getHoldingDays(1))
      .to.be.equal(20)
    expect(await this._voyagerStorage.getCurLevelHoldingDays(1))
      .to.be.equal(10)

    // dgt and dsp fee for level2up
    this.levelUpFeeRes = await this._voyagerStorage.getLevelUpFeeV2(1)
    console.log(this.levelUpFeeRes)
    this.dgtLevelUpFee = this.levelUpFeeRes[0]
    this.dspLevelUpFee = this.levelUpFeeRes[1]

    // mint dsp for level2up
    this.tx = await this.DSP.mintByMinter(this.ip1.address, this.dspLevelUpFee)
    await this.tx.wait()
    // dgt and dsp balance of ip1 before level2up
    this.dgtBefore = await this.DGT.balanceOf(this.ip1.address)
    this.dspBefore = await this.DSP.balanceOf(this.ip1.address)
    // approve token transfer before level2up
    this.tx = await this.DGT.connect(this.ip1).approve(
      this._voyager.address, this.dgtLevelUpFee);
    await this.tx.wait()
    this.tx = await this.DSP.connect(this.ip1).approve(
      this._voyager.address, this.dspLevelUpFee);
    await this.tx.wait()
    // ip1 held token to level up 
    this.tx = await this._voyager.connect(this.ip1).levelUp(1)
    await this.tx.wait()

    // dgt and dsp balance of ip1 after mint
    this.dgtAfter = await this.DGT.balanceOf(this.ip1.address)
    this.dspAfter = await this.DSP.balanceOf(this.ip1.address)
    // levelup1 fee cost correctly
    expect(this.dgtBefore.sub(this.dgtAfter))
      .to.be.equal(this.dgtLevelUpFee)
    expect(this.dspBefore.sub(this.dspAfter))
      .to.be.equal(this.dspLevelUpFee)
    console.log('level2up finished')
  
  })  

// 测试在ip1 token#1当前等级持有天数：
// 5. ip1 token#1转账给ip2,check持有时间及当前等级持有时间
// 6. ip2 升级token#1

  it("Transfer correct", async function() {
    // get level: Voyager instance of token held by ip1 of index 1
    console.log(await this._voyagerStorage.voyagers(1))
    console.log(await this._voyagerStorage.ownedVoyagers(this.ip1.address, 1))

    // let level = (await this._voyagerStorage.ownedVoyagers(this.ip1.address, 1))[0]
    // expect(level).to.be.equal(3)
    // // get token id
    let tokenId = (await this._voyagerStorage.ownedVoyagers(this.ip1.address, 1)).toNumber()
    expect(tokenId).to.be.equal(1)
    // console.log(tokenId)

    // transfer tokenId#1 to ip2
    this.tx = await this._voyager.setTokenURI(this.ip1.address, 1, 3, 'token#1Level#3')
    await this.tx.wait()

    this.tx = await this._voyagerStorage.connect(this.ip1).transferVoyager(this.ip2.address, tokenId)
    await this.tx.wait()

    // check balance of ip2
    expect(await this._voyagerStorage.balanceOf(this.ip2.address))
      .to.be.equal(1)
  
  })

  it("Max Level correct", async function() {
    // ip1 max level is 6
    let ip1MaxLevel = (await this._voyagerStorage.getValidMaxLevel(this.ip1.address,1)).toNumber()
    expect(ip1MaxLevel).to.be.equal(6)
    // ip2 max level is 0
    let ip2MaxLevel = (await this._voyagerStorage.getValidMaxLevel(this.ip2.address,1)).toNumber()
    console.log('ip2 max level is: ' + ip2MaxLevel)
    expect(ip2MaxLevel).to.be.equal(0)

    console.log('ip1 max level is: '+ip1MaxLevel)
    console.log('ip2 max level is: '+ip2MaxLevel)
  })
})
