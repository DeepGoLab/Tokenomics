require("@nomiclabs/hardhat-waffle");

const { GetConfig } = require("../config/auto-config.js")

task("upgrade-voyager", "Upgrade of voyager")
    .setAction(async (_, { ethers, getChainId}) => {
        const ID = await getChainId();
        // get address
        const VoyagerStorageAddress = await GetConfig(ID).VoyagerStorage;
        const VoyagerAddress = await GetConfig(ID).Voyager;
        // get instance 
        const VoyagerStorage = await ethers.getContractAt('Voyager', VoyagerStorageAddress);
        await VoyagerStorage.setProxy(VoyagerAddress).then(() => {
            console.log("Upgrade finished");
        });
});

task("pause-voyager", "Pasue all the external Voyager functions of voyager")
    .setAction(async (_, { ethers, getChainId}) => {
        const ID = await getChainId();
        const VoyagerAddress =  await GetConfig(ID).Voyager;
        const Voyager = await ethers.getContractAt('Voyager', VoyagerAddress);
        await Voyager.setPause().then(() => {
            console.log("Voyager successful paused");
        });
});

task("unpause-voyager", "Unpasue all the external Voyager functions of voyager")
    .setAction(async (_, { ethers, getChainId}) => {
        const ID = await getChainId();
        const VoyagerAddress =  await GetConfig(ID).Voyager;
        const Voyager = await ethers.getContractAt('Voyager', VoyagerAddress);
        await Voyager.unPause().then(() => {
            console.log("Voyager successful unpaused");
        });
});
