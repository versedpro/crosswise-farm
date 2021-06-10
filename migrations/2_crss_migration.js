const CrssToken = artifacts.require("CrssToken");

module.exports = async function(deployer) {
  deployer.deploy(CrssToken, '0xE999C20A79080b94908e244081EfD40369dA4170', '0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB', '0x000000000000000000000000000000000000dEaD');
};
