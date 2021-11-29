const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  const block = await web3.eth.getBlock("latest");
  await deployer.deploy(MasterChef, "0xA98D21C3D61A7EB9Dd3BE9C9a1132Abb7c7Be2Dd", "0x8c4A608335f641bA2304586178F7F23BCa862234", "0x2efBEa23f0CD3f80F7802cd3d56E4b53985Fd634", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x3D0b45BCEd34dE6402cE7b9e7e37bDd0Be9424F3", block.number + 100);
};
