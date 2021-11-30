var { BASE_TEN, ADDRESS_ZERO, getBigNumber, getDGTAddress, numToBigNumber, sign} = require("../test/utils")
require('dotenv').config();

module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    
    // let DGT = "0xB6d7Bf947d4D6321FD863ACcD2C71f022BCFd0eE"
    let ADMIN = "0x81422b9cEBF792BcC0AEb0555FA407FeBBf8db29"
    const DGT = getDGTAddress(await getChainId())

    const sig = await ethers.getContract("Sig")

    await deploy('DeepGoAirdrop', {
        from: deployer,
        args: [DGT, getBigNumber(100), getBigNumber(10000)],
        libraries: {"Sig": sig.address},
        log: true,
        deterministicDeployment: false
    })

    const deepGoAirdrop = await ethers.getContract("DeepGoAirdrop")
    // let tx = await deepGoAirdrop.transferAdmin(ADMIN)
    // await tx.wait()
}