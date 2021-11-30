var { BASE_TEN, ADDRESS_ZERO, getBigNumber, getDGTAddress, numToBigNumber, sign} = require("../test/utils")

module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    
    await deploy("Sig", {
        from: deployer,
        log: true,
        deterministicDeployment: false
    })

    const sig = await ethers.getContract("Sig")

    await deploy('Marketplace', {
        from: deployer,
        // args: [DGT, getBigNumber(100), getBigNumber(10000)],
        libraries: {"Sig": sig.address},
        log: true,
        deterministicDeployment: false
    })
}