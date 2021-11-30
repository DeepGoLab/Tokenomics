module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    // console.log('deployer is: '+deployer.address)

    await deploy("Sig", {
        from: deployer,
        log: true,
        deterministicDeployment: false
    })
}

module.exports.tags = ["Sig"]