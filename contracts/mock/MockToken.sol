pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";

contract MockToken is
    Initializable,
    ERC20Mintable,
    ERC20Detailed,
    Ownable
{
    address public token;
    address public to;
    uint256 public deadline;

    function() external payable {}

    function initialize() external initializer {
        ERC20Detailed.initialize('HongBao Token', 'HB', 18);
        _mint(msg.sender, 100000 ether);
        Ownable.initialize(msg.sender);
    }
    
    function adminWithdrawBnb()
        public
        onlyOwner
    {
        require(address(this).balance > 0, "Insufficient balance");
        msg.sender.transfer(address(this).balance);
    }
}
