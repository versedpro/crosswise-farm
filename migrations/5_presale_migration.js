const Presale = artifacts.require("Presale");

module.exports = async function(deployer) {
  const block = await web3.eth.getBlock("latest");
  await deployer.deploy(Presale, "0xA98D21C3D61A7EB9Dd3BE9C9a1132Abb7c7Be2Dd", "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee", "0x6973a5D5e2Bd3bBDe498104FeCDF3132A3c545aB", block.number);
};
