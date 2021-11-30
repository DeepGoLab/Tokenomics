module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    await deploy('DeepSeaPlankton', {
        from: deployer,
        log: true,
        deterministicDeployment: false
    })
}

module.exports.tags = ["Dsp"]