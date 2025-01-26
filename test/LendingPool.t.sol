// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "../src/LendingPool.sol";

contract LendingPoolTest is Test {
    address public usdc = 0x5e4695a76Dc81ECc041576d672Da1208d6d8922B; // our own USDC
    address public wbtc = 0x919c586538EE34B87A12c584ba6463e7e12338E9; // our own WBTC

    LendingPool public lendingPool;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/AGCKLQQJ44DToAoLdZbXDWaT5faaaZGh", 7573182);

        lendingPool = new LendingPool();

        deal(usdc, alice, 1000e6);
    }

    function test_supply() public {
        // deposit
        vm.startPrank(alice);
        IERC20(usdc).approve(address(lendingPool), 1000e6);
        lendingPool.supply(1000e6);
        vm.stopPrank();

        vm.startPrank(bob);
        lendingPool.borrow(100e6);
        vm.stopPrank();

        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("Alice userSupplyShares =", lendingPool.userSupplyShares(alice));

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
    }
}
