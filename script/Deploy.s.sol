// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/TestToken.sol";
import "../src/MockYieldVault.sol";
import "../src/YieldAdapter.sol";
import "../src/NoLossLottery.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        TestToken token = new TestToken(owner);
        MockYieldVault vault = new MockYieldVault(owner);
        YieldAdapter adapter = new YieldAdapter(address(vault), owner);
        NoLossLottery lottery = new NoLossLottery(address(adapter), owner);

        adapter.transferOwnership(address(lottery));
        vault.transferOwnership(address(adapter));

        vm.stopBroadcast();

        console2.log("Deployer:", owner);
        console2.log("TestToken:", address(token));
        console2.log("MockYieldVault:", address(vault));
        console2.log("YieldAdapter:", address(adapter));
        console2.log("NoLossLottery:", address(lottery));
    }
}