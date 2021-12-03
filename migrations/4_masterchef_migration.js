const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  const block = await web3.eth.getBlock("latest");
  await deployer.deploy(MasterChef, "0x34cF26E9A44Ec06F846bc82FaE649AdC6D2260b8", "0x7d314161ebb77C381b7150C89748B8A687c1f56F", "0x2efBEa23f0CD3f80F7802cd3d56E4b53985Fd634", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x3D0b45BCEd34dE6402cE7b9e7e37bDd0Be9424F3", block.number + 100);
};
