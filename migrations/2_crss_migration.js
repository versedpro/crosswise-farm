const CrssToken = artifacts.require("CrssToken");

module.exports = async function(deployer) {
  deployer.deploy(CrssToken);
};
