const MasterChef = artifacts.require("MasterChef");

module.exports = async function(deployer) {
  deployer.deploy(MasterChef, "0xBB0a02Ce9d2a2D99C16e86F954bD1B2Be8bC02f8", "0x370c9d8B2d1134631482B50c938736f8D145B40E", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", "9354573");
};
