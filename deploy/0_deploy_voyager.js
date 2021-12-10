var { BASE_TEN, ADDRESS_ZERO, getBigNumber, getDGTAddress, numToBigNumber, sign} = require("../test/utils")
require('dotenv').config();
require("@tenderly/hardhat-tenderly");
// const hre = require("@nomiclabs/hardhat");

module.exports = async function ({ tenderly, ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const signer = process.env.OWNER_PRIVATE_KEY
    const maxLevel = 6;
    const dgt = getDGTAddress(await getChainId())
    let ADMIN = "0x81422b9cEBF792BcC0AEb0555FA407FeBBf8db29"
    
    this.signers = await ethers.getSigners();
    this.ip1 = this.signers[1];

    await deploy("Sig", {
        from: deployer,
        log: true,
        deterministicDeployment: false
    })

    // todo：设置升级费用
    const sig = await ethers.getContract("Sig")

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

    this.tx = await voyager.setFee1TokenAddress(dgt)
    await this.tx.wait();
    this.tx = await voyager.setFee2TokenAddress('0xa1041fB61fd3FE7B3337D06959A615A7d4b46F9f')
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
    
    // await tenderly.push({
    //     name: 'Voyager',
    //     address: voyager.address,
    //   });

    // await tenderly.push({
    //     name: 'VoyagerStorage',
    //     address: voyagerStorage.address,
    //   });

    // todo: tranfer admin
    this.tx = await voyager.transferAdmin(ADMIN)
    await this.tx.wait()
    console.log('voyager transfer admin finished')

    // // push to tenderly
    // const contracts = [
    //     {
    //         name: 'sig',
    //         address: sig.address
    //     },
        // {
        //     name: "Voyager",
        //     address: voyager.address
        // },
        // {
        //     name: "VoyagerStorage",
        //     address: voyagerStorage.address
        // }
    // ]
    // console.log('hre is: '+hre)
    // await hre.tenderly.push(...contracts)
}
