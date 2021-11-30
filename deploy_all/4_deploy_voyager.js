var { BASE_TEN, ADDRESS_ZERO, getBigNumber, getDGTAddress, numToBigNumber, sign} = require("../test/utils")
require('dotenv').config();

module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    let ADMIN = "0x81422b9cEBF792BcC0AEb0555FA407FeBBf8db29"
    const signer = process.env.OWNER_PRIVATE_KEY
    this.signers = await ethers.getSigners();
    this.ip1 = this.signers[1];

    const maxLevel = 6;
    // todo：设置升级费用
    const levelUpFee = [10,100,20,200,30,300,40,400,50,500,60,600];
    const sig = await ethers.getContract("Sig")
    const dsp = await ethers.getContract("DeepSeaPlankton")
    const dgt = getDGTAddress(await getChainId())

    // dsp transfer admin
    this.tx = await dsp.changeAdmin(ADMIN)
    await this.tx.wait()
    console.log('dsp change admin finished')

    // dsp minters add admin
    this.tx = await dsp.addMinters([ADMIN])
    await this.tx.wait()

    await deploy("VoyagerLogic", {
        from: deployer,
        log: true,
        deterministicDeployment: false
    })

    const voyagerLogic = await ethers.getContract("VoyagerLogic")

    await deploy("VoyagerStorage", {
        from: deployer,
        libraries: {"Sig": sig.address},
        args: [maxLevel],
        log: true,
        deterministicDeployment: false
    })

    const voyagerStorage = await ethers.getContract("VoyagerStorage")
    // todo: 1. setLevelUpFee; 2. setCoolDown:暂时不加限制
    await deploy("Voyager", {
        from: deployer,
        libraries: {"Sig": sig.address},
        args: [voyagerStorage.address],
        log: true,
        deterministicDeployment: false
    })

    const voyager = await ethers.getContract("Voyager")
    this.tx =await voyagerStorage.setProxy(voyager.address)
    await this.tx.wait()

    // for (let i=0; i<maxLevel; i++) {
    //     await voyagerStorage.setLevelUpFee(i+1, levelUpFee[2*i], levelUpFee[2*i+1]);
    // }

    this.tx= await voyager.initialize(voyagerLogic.address)
    await this.tx.wait()
    this.tx = await voyager.setFee1TokenAddress(dgt)
    await this.tx.wait();
    this.tx = await voyager.setFee2TokenAddress(dsp.address)
    await this.tx.wait();
    console.log('DGT address is: '+(await voyagerStorage.dgtAddress()))
    console.log('DSP address is: '+(await voyagerStorage.dspAddress()))

    // todo: 完成token#0铸造
    this.tx = await voyager.setToken0URI("token0URI")
    await this.tx.wait()
    console.log('set token#0 URI finished')
    // todo: 用deployer的地址签名失败
    let signature = await sign(this.ip1.address, String(signer))
    console.log('signature: '+signature)

    this.tx = await voyager.connect(this.ip1).mintVoyagerByWhitelist(signature)
    await this.tx.wait();
    console.log('mint first NFT finished')
    
    // // todo: tranfer admin
    // this.tx = await voyager.transferAdmin(ADMIN)
    // await this.tx.wait()
    // console.log('voyager transfer admin finished')
}
