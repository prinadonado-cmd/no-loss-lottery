// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMockYieldVault {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount, address to) external;
    function totalAssets(address token) external view returns (uint256);
}

contract YieldAdapter is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();

    IMockYieldVault public immutable vault;

    event DepositedToVault(address indexed token, uint256 amount);
    event WithdrawnFromVault(address indexed token, uint256 amount);

    constructor(address vaultAddress, address initialOwner) Ownable(initialOwner) {
        if (vaultAddress == address(0)) revert ZeroAddress();
        vault = IMockYieldVault(vaultAddress);
    }

    function depositToVault(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // 1. Забираем токены у владельца (Lottery) через allowance
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // 2. Разрешаем vault забрать токены у adapter
        IERC20(token).forceApprove(address(vault), amount);

        // 3. Кладём в vault
        vault.deposit(token, amount);

        emit DepositedToVault(token, amount);
    }

    function withdrawFromVault(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // 1. Забираем токены из vault на adapter
        vault.withdraw(token, amount, address(this));

        // 2. Пересылаем их обратно владельцу (Lottery)
        IERC20(token).safeTransfer(msg.sender, amount);

        emit WithdrawnFromVault(token, amount);
    }

    function totalAssets(address token) external view returns (uint256) {
        return vault.totalAssets(token);
    }
}