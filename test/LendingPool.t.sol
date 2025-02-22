// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {PositionType} from "../src/interfaces/ILendingPool.sol";

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
        uint8 liquidationThresholdPercentage = 80;
        uint8 interestRate = 5;
        PositionType positionType = PositionType.LONG;

        lendingPool = new LendingPool(
            mockUSDC,
            mockWBTC,
            usdcUsdPriceFeed,
            wbtcUsdPriceFeed,
            liquidationThresholdPercentage,
            interestRate,
            positionType,
            alice
        );

        console.log("==================DEPLOYED ADDRESSES==========================");
        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("USDC/USD Price Feed deployed at:", address(usdcUsdPriceFeed));
        console.log("WBTC/USD Price Feed deployed at:", address(wbtcUsdPriceFeed));
        console.log("Lending Pool deployed at:", address(lendingPool));
        console.log("Liquidation Threshold Percentage:", liquidationThresholdPercentage);
        console.log("Interest Rate Percentage:", interestRate);
        console.log("Position Type (0 = LONG, 1 = SHORT):", uint8(positionType));
        console.log("==============================================================");

        mockUSDC.mint(alice, 100_000e6);
        mockWBTC.mint(alice, 1e6);
        mockUSDC.mint(bob, 100_000e6);
        mockWBTC.mint(bob, 2e6);
    }

    function supplyLiquidity(uint256 amount) internal {
        IERC20(mockUSDC).approve(address(lendingPool), amount);
        lendingPool.supply(amount);
    }

    function test_supply() public {
        uint256 initialDeposit = 100_000e6;

        // Alice supply liquidity
        vm.startPrank(alice);
        supplyLiquidity(initialDeposit);
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

        vm.warp(block.timestamp + 1 days);

        lendingPool.accrueInterest();

        console.log("totalSupplyAssets setelah 1 hari =", lendingPool.totalSupplyAssets());
        console.log("totalBorrowAssets setelah 1 hari =", lendingPool.totalBorrowAssets());
        console.log("Utilization Rate setelah 1 hari =", lendingPool.getUtilizationRate(), "%");
    }

    function test_withdraw() public {
        uint256 supplyAmount = 100_000e6;
        uint256 withdrawShares = 50_000e6;

        // Alice supplies liquidity
        vm.startPrank(alice);
        supplyLiquidity(supplyAmount);
        vm.stopPrank();

        // Ensure Alice's initial shares are correct
        assertEq(lendingPool.userSupplyShares(alice), supplyAmount, "Alice should have correct supply shares");

        // Alice withdraws a portion of her shares
        vm.startPrank(alice);
        lendingPool.withdraw(withdrawShares);
        vm.stopPrank();

        // Validate updated shares and balances
        assertEq(lendingPool.userSupplyShares(alice), supplyAmount - withdrawShares, "Alice's shares should decrease");
        assertEq(lendingPool.totalSupplyShares(), supplyAmount - withdrawShares, "Total shares should decrease");
        assertEq(IERC20(mockUSDC).balanceOf(alice), withdrawShares, "Alice should receive withdrawn USDC");

        // Ensure withdrawal of `0` shares fails
        vm.startPrank(alice);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        lendingPool.withdraw(0);
        vm.stopPrank();

        // Step 6: Ensure withdrawal of more than owned shares fails
        vm.startPrank(alice);
        vm.expectRevert(LendingPool.InsufficientShares.selector);
        lendingPool.withdraw(supplyAmount); // Trying to withdraw more than available
        vm.stopPrank();
    }

    function test_flashLoan() public {
        // give 100 USDC to lending pool
        deal(address(mockUSDC), address(lendingPool), 100e6);
        uint256 amount = 100e6;

        // encode parameter to bytes: address,uint256
        bytes memory params = abi.encode(address(this), amount);

        lendingPool.flashLoan(address(mockUSDC), amount, params);
    }

    // to receive flashloan
    function onFlashLoan(address token, uint256 amount, bytes calldata params) external {
        console.log("Flashloan received", amount);

        // decode parameter from bytes: address,uint256
        (address receiver, uint256 _amount) = abi.decode(params, (address, uint256));

        // mint
        mockUSDC.mint(receiver, _amount);

        IERC20(token).approve(address(lendingPool), amount);
    }
}
