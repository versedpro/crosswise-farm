pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libs/SafeBEP20.sol";
import "./libs/IBEP20.sol";

contract Presale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    event Deposited(
        address indexed user, 
        uint256 amount
    );

    IBEP20 crssToken;
    IBEP20 busd;
    
    mapping(address => uint256) public deposits;

    address[] public investors;

    address public masterWallet;
    
    uint256 public totalDepositedBusdBalance;

    uint256 public startTimestamp;
    uint256 public softCapAmount = 50000000000000000000000; // 50k busd
    uint256 public hardCapAmount = 200000000000000000000000; // 200k busd
    uint256 public tokenPrice = 500000000000000000; //0.5 busd
    // uint256 public hardCapPrice = 1000000000000000000; //1 busd
    uint256 public maxBusdPerWallet = 1000000000000000000000; //1k busd

    constructor(
        IBEP20 _crssToken,
        IBEP20 _busd,
        address _masterWallet,
        uint256 _startTimestamp
    ) public {
        require(address(_crssToken) != address(0), "Presale: Token address should not be zero address");
        require(address(_busd) != address(0), "Presale: busd token address should not be zero address");
        require(_masterWallet != address(0), "Presale: master wallet address should not be zero address");
        require(_startTimestamp >= _getNow(), "Presale: Presale start time invalid");

        crssToken = _crssToken;
        busd = _busd;
        masterWallet = _masterWallet;
        startTimestamp = _startTimestamp;

    }

    function investorCount() public view returns (uint256) {
        return investors.length;
    }

    function allInvestors() public view returns (address[] memory) {
        return investors;
    }
    
    function updateSoftCapAmount(uint256 _softCapAmount) public onlyOwner {
        require(_softCapAmount > 0, "Presale.updateSoftCapAmount: soft cap amount invalid");
        softCapAmount = _softCapAmount;
    }

    function updateHardCapAmount(uint256 _hardCapAmount) public onlyOwner {
        require(_hardCapAmount > 0, "Presale.updateHardCapAmount: soft cap amount invalid");
        hardCapAmount = _hardCapAmount;
    }

    function updateTokenPrice(uint256 _tokenPrice) public onlyOwner {
        require(_tokenPrice > 0, "Presale.updateSoftCapAmount: soft cap amount invalid");
        tokenPrice = _tokenPrice;
    }

    function deposit(uint256 _amount) public payable nonReentrant {
        require(now >= startTimestamp, "Presale.deposit: Presale is not active");
        require(totalDepositedBusdBalance + _amount <= hardCapAmount, "deposit is above hardcap limit");
        require(deposits[msg.sender] + _amount <= maxBusdPerWallet, "Presale.deposit: deposit amount is bigger than max deposit amount");

        uint256 rewardTokenAmount = _amount.mul(1e18).div(tokenPrice);

        busd.safeTransferFrom(msg.sender, masterWallet, _amount);
        crssToken.safeTransferFrom(masterWallet, msg.sender, rewardTokenAmount);

        totalDepositedBusdBalance = totalDepositedBusdBalance + _amount;
        if(deposits[msg.sender] == 0) {
            investors.push(msg.sender);
        }
        deposits[msg.sender] = deposits[msg.sender] + _amount;
        
        emit Deposited(msg.sender, _amount);
    }

    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }
}