const CrssToken = artifacts.require("CrssToken");

module.exports = async function(deployer) {
  deployer.deploy(CrssToken, '0x2A479056FaC97b62806cc740B11774E6598B1649', '0x000000000000000000000000000000000000dEaD');
};
