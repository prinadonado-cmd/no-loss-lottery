// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/TestToken.sol";
import "../src/MockYieldVault.sol";
import "../src/NoLossLottery.sol";

contract SetupDemoScript is Script {
    function run() external {
        uint256 ownerKey = vm.envUint("PRIVATE_KEY");
        uint256 user1Key = vm.envUint("PRIVATE_KEY_USER1");
        uint256 user2Key = vm.envUint("PRIVATE_KEY_USER2");

        address owner = vm.addr(ownerKey);
        address user1 = vm.addr(user1Key);
        address user2 = vm.addr(user2Key);

        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address lotteryAddress = vm.envAddress("LOTTERY_ADDRESS");

        TestToken token = TestToken(tokenAddress);
        MockYieldVault vault = MockYieldVault(vaultAddress);
        NoLossLottery lottery = NoLossLottery(lotteryAddress);

        vm.startBroadcast(ownerKey);

        token.mint(user1, 1_000 ether);
        token.mint(user2, 1_000 ether);

        uint256 roundId = lottery.createRound(
            tokenAddress,
            block.timestamp + 3 minutes,
            block.timestamp + 5 minutes
        );

        vm.stopBroadcast();

        vm.startBroadcast(user1Key);
        token.approve(lotteryAddress, 100 ether);
        lottery.deposit(roundId, 100 ether);
        vm.stopBroadcast();

        vm.startBroadcast(user2Key);
        token.approve(lotteryAddress, 200 ether);
        lottery.deposit(roundId, 200 ether);
        vm.stopBroadcast();

        console2.log("Owner:");
        console2.logAddress(owner);

        console2.log("User1:");
        console2.logAddress(user1);

        console2.log("User2:");
        console2.logAddress(user2);

        console2.log("Round created:");
        console2.logUint(roundId);

        console2.log("User1 deposited 100 ether");
        console2.log("User2 deposited 200 ether");

        console2.log("IMPORTANT:");
        console2.log("Wait until deposit deadline passes, then call investRound manually.");
        console2.log("After that, mint yield to owner, approve vault, call addYield.");
        console2.log("Then wait until roundEnd and call finalizeRound.");
    }
}