const CrssVault = artifacts.require("CrssVault");

module.exports = async function(deployer) {
  await deployer.deploy(CrssVault, "0x9D1b283685633501C0Ed1Da79884BF2e70c78d34", "0xb3cA8613b9d156552598720a312A59A135d6189b", "0x893C9F052e8792dcC8CC86f3872eB67b4cDc870C", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB");
};
