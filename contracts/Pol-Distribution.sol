// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.28;

contract PolDistribution {
    address public admin;
    IERC20 public usdtToken;
    uint256 public startTime;
    uint256 public endTime;
    mapping(address => uint256) public allocations;
    mapping(address => bool) public claimed;

    event AdminChanged(address indexed newAdmin);
    event UsdtTokenChanged(address indexed newUsdtToken);
    event StartTimeChanged(uint256 newStartTime);
    event EndTimeChanged(uint256 newEndTime);
    event AllocationsSet(address[] recipients, uint256[] amounts);
    event AllocationsRemoved(address[] recipients);
    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);

    event Claimed(address indexed recipient, uint256 amount);

    // --------- Modifiers ------------------------------------------------------
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }
    modifier withinWindow() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Not within claim window"
        );
        _;
    }

    // --------- Constructor ------------------------------------------------------
    constructor(address _usdtToken, uint256 _startTime, uint256 _endTime) {
        require(_startTime < _endTime, "Invalid time window");
        admin = msg.sender;
        usdtToken = IERC20(_usdtToken);
        startTime = _startTime;
        endTime = _endTime;
    }

    // --------- Setters ------------------------------------------------------
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit AdminChanged(_admin);
    }

    function setUsdtToken(address _usdtToken) external onlyAdmin {
        usdtToken = IERC20(_usdtToken);
        emit UsdtTokenChanged(_usdtToken);
    }

    function setStartTime(uint256 _startTime) external onlyAdmin {
        require(_startTime < endTime, "Invalid time window");
        startTime = _startTime;
        emit StartTimeChanged(_startTime);
    }

    function setEndTime(uint256 _endTime) external onlyAdmin {
        require(startTime < _endTime, "Invalid time window");
        endTime = _endTime;
        emit EndTimeChanged(_endTime);
    }

    // --------- Permissioned functions ------------------------------------------------------
    function deposit(uint256 amount) external onlyAdmin {
        require(
            usdtToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        emit Deposited(amount);
    }

    function setAllocations(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyAdmin {
        require(
            recipients.length == amounts.length,
            "Mismatched input lengths"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            allocations[recipients[i]] = amounts[i];
        }
        emit AllocationsSet(recipients, amounts);
    }

    function removeAllocations(
        address[] calldata recipients
    ) external onlyAdmin {
        for (uint256 i = 0; i < recipients.length; i++) {
            allocations[recipients[i]] = 0;
        }
        emit AllocationsRemoved(recipients);
    }

    function withdraw(uint256 amount) external onlyAdmin {
        require(block.timestamp > endTime, "Claim window still open");
        require(usdtToken.transfer(admin, amount), "Transfer failed");
        emit Withdrawn(amount);
    }

    // --------- User functions ------------------------------------------------------
    function claim() external withinWindow {
        require(!claimed[msg.sender], "Already claimed");
        uint256 amount = allocations[msg.sender];
        require(amount > 0, "No allocation");
        claimed[msg.sender] = true;
        require(usdtToken.transfer(msg.sender, amount), "Transfer failed");
        emit Claimed(msg.sender, amount);
    }
}
