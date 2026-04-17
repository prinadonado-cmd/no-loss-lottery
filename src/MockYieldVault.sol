// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockYieldVault is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error ZeroAddress();
    error InsufficientVaultBalance();

    mapping(address => uint256) public tokenBalances;

    event Deposited(address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);
    event YieldAdded(address indexed token, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function deposit(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;

        emit Deposited(token, amount);
    }

    function withdraw(address token, uint256 amount, address to) external onlyOwner {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (tokenBalances[token] < amount) revert InsufficientVaultBalance();

        tokenBalances[token] -= amount;
        IERC20(token).safeTransfer(to, amount);

        emit Withdrawn(token, amount);
    }

    function addYield(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;

        emit YieldAdded(token, amount);
    }

    function totalAssets(address token) external view returns (uint256) {
        return tokenBalances[token];
    }
}