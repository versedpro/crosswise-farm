const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  const block = await web3.eth.getBlock("latest");
  await deployer.deploy(MasterChef, "0x9D1b283685633501C0Ed1Da79884BF2e70c78d34", "0xb3cA8613b9d156552598720a312A59A135d6189b", "0x2efBEa23f0CD3f80F7802cd3d56E4b53985Fd634", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x3D0b45BCEd34dE6402cE7b9e7e37bDd0Be9424F3", block.number + 100);
};
