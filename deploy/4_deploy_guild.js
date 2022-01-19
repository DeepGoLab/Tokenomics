const { ethers } = require('hardhat');
var { getDGTAddress, sign} = require("../test/utils")

// npx hardhat console --network rinkeby
// npx hardhat run --network rinkeby deploy/4_deploy_guild.js
async function main() {
  const { deployer } = await getNamedAccounts()
  let signers = await ethers.getSigners()
  let deployerSigner = signers[0]
  console.log(`deploy address: ${deployer}`)

  const dgtAddress = getDGTAddress(await getChainId())
  let dgtContract = await ethers.getContractAt('IERC20', dgtAddress);
  // DSP on rinkeby
  const dspAddress = '0x864e8dad3f3b8ca715a4935a17b0a9c24e83dd7b'
  console.log('deploy on chain: ', await getChainId())
  console.log(`DGT address: ${dgtAddress}`)
  console.log(`DSP address: ${dspAddress}`)

  const sigLib = await ethers.getContractFactory("Sig")
  const sig = await sigLib.deploy();
  console.log("Sig deployed at:", sig.address);

  const pilotStorage = await ethers.getContractFactory("PilotStorage", {
    libraries: {
      Sig: sig.address
    }
  });
  const ps = await pilotStorage.deploy();
  console.log("PilotStorage deployed at:", ps.address);

  const voyagerStorage = await ethers.getContractFactory("VoyagerStorage", {
    libraries: {
      Sig: sig.address
    }
  });
  const vs = await voyagerStorage.deploy();
  console.log("VoyagerStorage deployed at:", vs.address);

  const treasuryStorage = await ethers.getContractFactory("TreasuryStorage", {
    libraries: {
      Sig: sig.address
    }
  });
  const ts = await treasuryStorage.deploy(ps.address, vs.address);
  console.log("TreasuryStorage deployed at:", ts.address);

  const pilotWhale = await ethers.getContractFactory("PilotWhale", {
    libraries: {
      Sig: sig.address
    }
  });
  const pw = await pilotWhale.deploy(ps.address, vs.address, ts.address);
  console.log("PilotWhale deployed at:", pw.address);

  // set proxy
  let tx = await vs.setProxy(pw.address)
  await tx.wait()
  tx = await ps.setProxy(pw.address)
  await tx.wait()
  // ts = await ethers.getContractAt("TreasuryStorage", '0x3f6EE6Ce23E1b4c24C08c9e99002a0005Bda7469')
  tx = await ts.setProxy(pw.address)
  await tx.wait()
  console.log('set proxy for Storage Contract success')

  // set DGT/DSP address for PilotStorage
  tx = await ps.setDgtAddress(dgtAddress)
  await tx.wait()
  tx = await ps.setDspAddress(dspAddress)
  await tx.wait()
  console.log('set DGT, DSP address for PilotStorage success')
  // set level -> exp
  tx = await ps.setLevelUpExp(1, 0)
  await tx.wait()

  // init token#0 for pilot and voyager NFT
  // pilot
  tx = await pw.setToken0URI("token0URI", true)
  await tx.wait()
  let pilotSig = await sign(deployer, String(process.env.OWNER_PRIVATE_KEY))
  tx = await pw.mintPilotByWhitelist(pilotSig, 'p0', 0, 0, 0)
  await tx.wait()
  // pay DGT to mint voyager
  let voyagerDGTFee = await vs.baseMintFee()
  console.log('voyagerDGTFee is: '+ voyagerDGTFee)
  tx = await dgtContract.connect(deployerSigner).approve(pw.address, voyagerDGTFee)
  tx = await pw.setToken0URI("token0URI", false)
  await tx.wait()
  tx = await pw.mintVoyager(0, 0)
  await tx.wait()
  console.log('set token#0 URI finished')

  // transfer admin
  let ADMIN_ADDRESS = "0x81422b9cEBF792BcC0AEb0555FA407FeBBf8db29"
  tx = await pw.transferAdmin(ADMIN_ADDRESS)
  await tx.wait()
  console.log('pilotWhale admin at: ', ADMIN_ADDRESS)
  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
