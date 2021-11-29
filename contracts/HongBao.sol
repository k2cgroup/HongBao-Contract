pragma solidity ^0.5.16;
/// 使用0.4.24是为了moac链 - www.moac.io
import "./interfaces/IBEP20.sol";

/// @title Hong Bao Contract
/// @author astonish
contract HongBao {
    address payable public owner;

    uint256 public minPackAmount = 1 * (10**18); // Minimal participant balance, 1 moac/mfc
    uint256 public maxPackAmount = 10000 * (10**18); // Maximum participant balance, 10000 moac/mfc
    uint256 public constant LIMIT_AMOUNT_OF_PACK = 100000 * (10**18);

    uint256 public minPackCount = 1; // Minimal count of red pack - 1
    uint256 public maxPackCount = 10000; // Maximum count of red pack - 10000

    uint256 public totalPackBNBAmounts = 0; // balance of this contract
    mapping(address => uint256) public totalPackTokenAmounts; // Total Token balance of this contract
    uint256 public numberOfPlayers = 0; // total count of red pack
    address[] public players; // all addresses of red pack creator

    IBEP20BSCswap public depositToken;

    modifier onlyOwner {
        require(msg.sender == owner, "You are not owner.");
        _;
    }

    struct Player {
        uint256 id; // red pack id
        address owner; // red pack's owner
        uint256 amount; // total balance of this red pack
        uint256 balance; // remained balance of this red pack
        uint256 count; // count of this red pack's reward package
        uint256 amountPerPack; // If equal distribute, the amount of each reward package
        bool isRandom; // random distribute(true)? or equal distribute(false)?
        uint256[] randomAmount; // if random distribute, distributed amount of each reward package
        uint256 randomFactor; // The sum of all random numbers/count, used to calculate the final distribution number
        IBEP20BSCswap mainToken; // the main token of this red pack
        address[] hunterList; // all list of hunters(who get reward from this red pack)
        mapping(address => uint256) hunterInfo; // detail info who get reward from this red pack
    }

    // Detailed mapping of red envelope id to red envelope sender
    mapping(uint256 => Player) public playerInfo;

    // This is for people to collect when they send bnb to the contract address
    function() external payable {}

    // event Received(address, uint);
    // receive() external payable { // receive关键字是solidity 6.0引进的
    //    emit Received(msg.sender, msg.value);
    // }
    // fallback() external payable;

    /// @notice constructor
    /// @param _minPackAmount min available balance of red pack
    /// @param _maxPackAmount max available balance of red pack
    constructor(uint256 _minPackAmount, uint256 _maxPackAmount) public {
        owner = msg.sender;

        if (_minPackAmount > 0) minPackAmount = _minPackAmount;
        if (_maxPackAmount > 0 && _maxPackAmount <= LIMIT_AMOUNT_OF_PACK)
            maxPackAmount = _maxPackAmount;
    }

    function kill() public {
        if (msg.sender == owner) selfdestruct(owner);
    }

    // Owner functions --------------------------------
    function setDepositToken(IBEP20BSCswap _depositToken) external onlyOwner {
        depositToken = _depositToken;
    }

    // General user's functions -----------------------
    function isBNBMode(IBEP20BSCswap _token) public pure returns (bool) {
        return (address(_token) == address(0));
    }

    /// @notice total number of red packs
    function getPlayerInfo()
        external
        view
        returns (
            uint256 nTotalPackAmounts,
            uint256 nNumberOfPlayers,
            address[] memory playerList
        )
    {
        return (totalPackBNBAmounts, numberOfPlayers, players);
    }

    //********************************************************************/
    // create red pack
    //********************************************************************/

    event redpackCreated(uint256 id);
    event redpackWithdraw(uint256 amount);

    /// @notice send red pack to recharge
    /// @param count the count of possible included reward package
    /// @param isRandom whether random or equal distribute
    function toll(
        uint256 count,
        bool isRandom,
        uint256 _amount,
        IBEP20BSCswap _mainToken
    ) external payable {
        uint256 _totalAmount = _amount;
        if (isBNBMode(_mainToken)) {
            _totalAmount = msg.value;
        }

        require(
            _totalAmount >= minPackAmount && _totalAmount <= maxPackAmount,
            "amount out of range(1..10000)"
        );
        require(
            count >= minPackCount && count <= maxPackCount,
            "Count is min 1, max 10000"
        );

        uint256 id = numberOfPlayers;
        playerInfo[id].amount = _totalAmount;
        playerInfo[id].balance = _totalAmount;
        playerInfo[id].mainToken = _mainToken;
        playerInfo[id].count = count;
        playerInfo[id].isRandom = isRandom;
        playerInfo[id].id = id;
        if (isRandom) {
            uint256 total = 0;
            for (uint256 i = 0; i < count; i++) {
                playerInfo[id].randomAmount[i] =
                    uint256(keccak256(abi.encodePacked(now, msg.sender, i))) %
                    100;
                total += playerInfo[id].randomAmount[i];
            }
            playerInfo[id].randomFactor = 100 / total; // use the random number as a percentage.
        } else {
            playerInfo[id].amountPerPack = _totalAmount / count; // If it is divided equally, what is the amount of each
        }

        if (isBNBMode(_mainToken)) totalPackBNBAmounts += _totalAmount;
        else totalPackTokenAmounts[address(_mainToken)] += _totalAmount;
        numberOfPlayers++; // Increase in the number of red envelopes created
        players.push(msg.sender); // increase creator list

        emit redpackCreated(id);
    }

    /// @notice The creator withdraws the remaining amount
    /// @param id red pack id
    function withdrawBalance(uint256 id) external {
        require(msg.sender == playerInfo[id].owner, "not the owner.");
        IBEP20BSCswap _mainToken = playerInfo[id].mainToken;
        require(playerInfo[id].balance > 0, "balance is 0.");
        if (isBNBMode(_mainToken)) {
            require(
                playerInfo[id].balance <= totalPackBNBAmounts,
                "not enough balance."
            );
            msg.sender.transfer(playerInfo[id].balance);
            totalPackBNBAmounts -= playerInfo[id].balance;
        } else {
            require(
                playerInfo[id].balance <=
                    totalPackTokenAmounts[address(_mainToken)],
                "not enough balance."
            );
            _mainToken.transfer(msg.sender, playerInfo[id].balance);
            totalPackTokenAmounts[address(_mainToken)] -= playerInfo[id]
                .balance;
        }

        emit redpackWithdraw(playerInfo[id].balance);
    }

    /// @notice Statistics of a certain red envelope
    /// @param id - red pack idid
    // returns:
    // remained balance
    // balance
    // count of reward package
    // if equal, amount of each reward package
    // random / equal
    function getPackInfo(uint256 id)
        external
        view
        returns (
            uint256 amount,
            uint256 balance,
            uint256 count,
            uint256 amountPerPack,
            bool isRandom,
            IBEP20BSCswap mainToken
        )
    {
        Player storage player = playerInfo[id];
        return (
            player.amount,
            player.balance,
            player.count,
            player.amountPerPack,
            player.isRandom,
            player.mainToken
        );
    }

    //********************************************************************/
    // Grab red pack
    //********************************************************************/

    event redpackGrabbed(uint256 amount);

    /// @notice Check whether the address has already grabbed the reward package.
    /// @param _id red pack id
    /// @param _hunter address Who grabs the red envelope
    function checkHunterExists(uint256 _id, address _hunter)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < playerInfo[_id].hunterList.length; i++) {
            if (playerInfo[_id].hunterList[i] == _hunter) return true;
        }
        return false;
    }

    /// @notice Grab the reward package. Note: After grabbing the reward package, the grabbed data is still retained for inquiries
    /// @param id red pack id
    function hunting(uint256 id) public payable {
        // First check if the red envelope has a balance
        require(playerInfo[id].balance > 0, "redpack is empty");
        require(
            playerInfo[id].count > playerInfo[id].hunterList.length,
            "exceed number of redpacks"
        );
        require(!checkHunterExists(id, msg.sender), "already grabbed");

        if (playerInfo[id].isRandom) {
            // Calculate the amount grabbed according to the random factor, there may be slight errors here
            uint256 index = playerInfo[id].hunterList.length;
            uint256 value =
                playerInfo[id].randomFactor *
                    playerInfo[id].randomAmount[index] *
                    playerInfo[id].amount;
            if (playerInfo[id].hunterList.length + 1 >= playerInfo[id].count) {
                // Taking into account the calculation error, grab the red envelope for the last time and send out all the balance
                hunted(id, playerInfo[id].balance);
                playerInfo[id].balance = 0;
            } else {
                hunted(id, value);
                playerInfo[id].balance -= value;
            }
        } else {
            // Taking into account the calculation error (for example, 100 yuan is sent to the average score of 3 people), grab the red envelope for the last time and send out all the balance
            if (playerInfo[id].balance > playerInfo[id].amountPerPack) {
                // If the balance is> 1 copy, but less than 2 copies, it will be sent all at once
                if (playerInfo[id].balance < playerInfo[id].amountPerPack * 2) {
                    hunted(id, playerInfo[id].balance);
                    playerInfo[id].balance = 0; // Sending is complete, the balance is 0
                } else {
                    // If the balance> 2 copies, send one copy
                    hunted(id, playerInfo[id].amountPerPack);
                    playerInfo[id].balance -= playerInfo[id].amountPerPack;
                }
            } else {
                // It is equal to the last person to grab the red envelope (less than impossible)
                hunted(id, playerInfo[id].balance);
                playerInfo[id].balance = 0;
            }
        }
    }

    function hunted(uint256 _id, uint256 _amount) internal {
        IBEP20BSCswap _mainToken = playerInfo[_id].mainToken;
        if (isBNBMode(_mainToken)) {
            require(
                _amount <= totalPackBNBAmounts,
                "grab: not enough balance."
            );
            msg.sender.transfer(_amount);
            totalPackBNBAmounts -= _amount;
        } else {
            require(
                _amount <= totalPackTokenAmounts[address(_mainToken)],
                "grab: not enough balance."
            );
            _mainToken.transfer(msg.sender, _amount);
            totalPackTokenAmounts[address(_mainToken)] -= _amount;
        }
        playerInfo[_id].hunterList.push(msg.sender);

        emit redpackGrabbed(_amount);
    }

    /// @notice The record of grabbing red envelopes, that is,
    /// at what time and how much money was grabbed-this can be judged by querying my specific transaction records
    // function huntingRecord(uint id) public view returns () {
    // }
}
