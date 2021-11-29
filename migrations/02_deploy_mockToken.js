const { scripts, ConfigManager } = require('@openzeppelin/cli');
const { add, push, create } = scripts;
const {publicKey} = require("../privatekey")

const contractName = 'MockToken';

const Contract = artifacts.require(contractName)

async function deploy(options) {
  add({ contractsData: [{ name: contractName, alias: contractName }] });
  options.force = true;
  await push(options);
  await create(Object.assign({ contractAlias: contractName }, options));
}

module.exports = function(deployer, networkName, accounts) {
  deployer.then(async () => {
    let account = accounts[0]
    const { network, txParams } = await ConfigManager.initNetworkConfiguration({ network: networkName, from: account })
    console.log('-- contract', contractName, 'deployed');
    await deploy({ network, txParams })
    let contractDeployed = await deployer.deploy(Contract);
    await contractDeployed.initialize();
    console.log('-- contract', contractName, 'initialized');
  })
}
