const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  const block = await web3.eth.getBlock("latest");
  await deployer.deploy(MasterChef, "0xbC0Da6F1881590A851AbE5AA05a7D88Bea5E4Ce0", "0x19A0Eb0869647e1B2e91582EaF004B060b126DDc", "0x2efBEa23f0CD3f80F7802cd3d56E4b53985Fd634", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x3D0b45BCEd34dE6402cE7b9e7e37bDd0Be9424F3", block.number + 100);
};
