const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  deployer.deploy(MasterChef, "0x74A8172C7EF1FD2637a2e605819ac2f9bc4A113f", "0x8c4A608335f641bA2304586178F7F23BCa862234", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x000000000000000000000000000000000000dEaD", "9618122");
};
