// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {LendingPool} from "../src/LendingPool.sol";

contract LendingPoolTest is Test {
    ERC20Mock public mockUSDC;
    ERC20Mock public mockWBTC;
    MockV3Aggregator public usdcUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    LendingPool public lendingPool;

    uint8 public DECIMALS = 8;
    int64 public constant USDC_USD_PRICE = 1e8;
    int64 public constant WBTC_USD_PRICE = 1e13;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        mockUSDC = new ERC20Mock();
        mockWBTC = new ERC20Mock();
        usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        wbtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, WBTC_USD_PRICE);

        lendingPool = new LendingPool(mockUSDC, mockWBTC, usdcUsdPriceFeed, wbtcUsdPriceFeed);

        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));

        // mockUSDC.mint(address(this), 1000_000e6);
        // mockWBTC.mint(address(this), 10);

        // mockUSDC.mint(address(lendingPool), 1000_000e6);
        // mockWBTC.mint(address(lendingPool), 10);

        mockUSDC.mint(alice, 100_000e6);
        mockWBTC.mint(alice, 1);

        mockUSDC.mint(bob, 100_000e6);
        mockWBTC.mint(bob, 2);
    }

    function test_supply() public {
        uint256 initialDeposit = 100_000e6;
        uint256 borrowAmount = 20_000e6;

        // Alice deposit
        vm.startPrank(alice);
        IERC20(mockUSDC).approve(address(lendingPool), initialDeposit);

        // Alice supply to lending pool
        lendingPool.supply(initialDeposit);
        vm.stopPrank();

        // Verify Alice's balance in LendingPool
        uint256 aliceShares = lendingPool.userSupplyShares(alice);
        assertEq(aliceShares, initialDeposit, "Alice should receive correct shares");

        // Verify LendingPool's totalSupplyAssets
        assertEq(lendingPool.totalSupplyAssets(), initialDeposit, "Total supply should update");

        // Ensure LendingPool received USDC
        assertEq(IERC20(mockUSDC).balanceOf(address(lendingPool)), initialDeposit, "LendingPool should receive USDC");

        // Check Alice's USDC balance (should decrease)
        uint256 aliceBalanceAfter = IERC20(mockUSDC).balanceOf(alice);
        assertEq(aliceBalanceAfter, 0, "Alice should have no USDC left after supplying");

        // Bob Borrow
        vm.startPrank(bob);
        lendingPool.borrow(borrowAmount);
        vm.stopPrank();

        console.log("totalSupplyAssets =", lendingPool.totalSupplyAssets());
        console.log("Alice userSupplyShares =", lendingPool.userSupplyShares(alice));

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
    }
}
