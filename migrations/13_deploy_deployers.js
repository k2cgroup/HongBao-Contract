const { scripts, ConfigManager } = require('@openzeppelin/cli');
const { add, push, create } = scripts;
const { publicKey } = require("../privatekey")

async function deploy(options, contractName) {
  add({ contractsData: [{ name: contractName, alias: contractName }] });
  options.force = true;
  await push(options);
  await create(Object.assign({ contractAlias: contractName }, options));
}

module.exports = function (deployer, networkName, accounts) {
  deployer.then(async () => {
    let account = accounts[0]
    const { network, txParams } = await ConfigManager.initNetworkConfiguration({ network: networkName, from: account })
    const contracts = ['HongBao']
    for (var i = 0; i < contracts.length; i++) {
      let contractName = contracts[i];
      await deploy({ network, txParams }, contractName)
      let JulPadDeployer = artifacts.require(contractName)
      let contractDeployed = await JulPadDeployer.deployed()
      console.log('-- contract', contractName, 'deployed');
      // await contractDeployed.initialize();
      // console.log('-- contract', contractName, 'initialized');
    }
  })
}
