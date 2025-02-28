// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {MockUniswapRouter} from "../src/mocks/MockUniswapRouter.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PositionFactory} from "../src/PositionFactory.sol";
import {LendingPoolFactory} from "../src/LendingPoolFactory.sol";
import {ILendingPool, PositionType} from "../src/interfaces/ILendingPool.sol";
import {IPosition} from "../src/interfaces/IPosition.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Position} from "../src/Position.sol";

/*
 * We cannot debug unverified contract hence it's important to create REPL file for setup
 */
contract REPLDeploy is Script {
    struct LendingPoolConfig {
        address loanToken;
        address collateralToken;
        address loanTokenPriceFeed;
        address collateralTokenPriceFeed;
    }

    LendingPoolConfig[] private lendingPoolSeeds;

    // Flame Testnet
    // address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x82069D54DF7fB4d9D9d8B35e2BecA6FE6aBAdF87;
    // address private constant POSITION_FACTORY_ADDR = 0x991de844C6A42AC2D4Bb6B97cE4fCf28296b8B84;
    // Arbitrum Sepolia
    address private constant MOCK_UNISWAP_ROUTER_ADDR = 0x5D680e6aF2C03751b9aE474E5751781c594df210;
    address private constant POSITION_FACTORY_ADDR = 0x21F5faEAA402e5950Aa8d6A3e6760699A5e1A0F6;
    address private constant LP_FACTORY_ADDR = 0x9C418f5400135989e7fc44221e9B4F90577610D7;

    function init() public {
        uint256 supplyAmount = 10_000e18;
        uint256 baseCollateral = 1e12;
        uint256 leverage = 200;

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LP_FACTORY_ADDR);
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory(MOCK_UNISWAP_ROUTER_ADDR);
        address lendingPoolAddr = lendingPoolFactory.createLendingPool(
            0xE6DFbEE9D497f1b851915166E26A273cB03F27E1,
            0x472A3ec37E662b295fd25E3b5d805117345a89D1,
            0x6A285E46Fce971CC762653EE9b8F81207A45214E,
            0x32423580b2762696Bf9F6e9149884d54e8150a19,
            80,
            5,
            PositionType.LONG
        );
        address loanToken = ILendingPool(lendingPoolAddr).loanToken();
        address collateralToken = ILendingPool(lendingPoolAddr).collateralToken();
        console.log("Lending Pool Factory deployed at:", address(lendingPoolFactory));
        console.log("Lending Pool deployed at:", lendingPoolAddr);

        console.log("Loan Token Balance before mint =", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance before mint =", MockERC20(collateralToken).balanceOf(address(this)));
        MockERC20(loanToken).mint(address(this), supplyAmount);
        MockERC20(collateralToken).mint(address(this), baseCollateral);
        console.log("Loan Token Balance after mint =", MockERC20(loanToken).balanceOf(address(this)));
        console.log("Collateral Token Balance after mint =", MockERC20(collateralToken).balanceOf(address(this)));

        MockERC20(loanToken).approve(lendingPoolAddr, supplyAmount);
        ILendingPool(lendingPoolAddr).supply(supplyAmount);

        console.log("====================== After Supply =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("==============================================================");

        // PositionFactory positionFactory = PositionFactory(POSITION_FACTORY_ADDR);
        PositionFactory positionFactory = new PositionFactory();
        MockERC20(collateralToken).approve(address(this), baseCollateral);
        MockERC20(collateralToken).approve(address(positionFactory), baseCollateral);
        console.log("Position Factory deployed at:", address(positionFactory));

        address onBehalf = positionFactory.createPosition(lendingPoolAddr, baseCollateral, leverage);
        console.log("Position deployed at:", onBehalf);
        console.log("====================== After Create Position =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("baseCollateral =", IPosition(onBehalf).baseCollateral());
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
        console.log("borrowShares =", IPosition(onBehalf).borrowShares());
        console.log("==============================================================");

        positionFactory.deletePosition(lendingPoolAddr, onBehalf);
        console.log("====================== After Delete Position =========================");
        console.log("totalCollateral =", ILendingPool(lendingPoolAddr).totalCollateral());
        console.log("totalSupplyAssets =", ILendingPool(lendingPoolAddr).totalSupplyAssets());
        console.log("totalBorrowAssets =", ILendingPool(lendingPoolAddr).totalBorrowAssets());
        console.log("baseCollateral =", IPosition(onBehalf).baseCollateral());
        console.log("effectiveCollateral =", IPosition(onBehalf).effectiveCollateral());
        console.log("borrowShares =", IPosition(onBehalf).borrowShares());
        console.log("==============================================================");
        vm.stopBroadcast();
    }

    function createBulkLendingPools() public {
        uint256 supplyAmount = 10_000e18;

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        LendingPoolFactory lendingPoolFactory = LendingPoolFactory(LP_FACTORY_ADDR);

        lendingPoolSeeds.push(
            LendingPoolConfig(
                0xE6DFbEE9D497f1b851915166E26A273cB03F27E1, // USDC Token
                0x472A3ec37E662b295fd25E3b5d805117345a89D1, // WBTC Token
                0x6A285E46Fce971CC762653EE9b8F81207A45214E, // USDC Aggregator
                0x32423580b2762696Bf9F6e9149884d54e8150a19 // WBTC Aggregator
            )
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(
                0xc0233309cD5e1fa340E2b681Dba3D4240aB6F49d, // USDT
                0x472A3ec37E662b295fd25E3b5d805117345a89D1, // WBTC
                0xB6D68C67BCA08023d2C51C9B487515A20Cc2bc2E, // USDT Aggregator
                0x32423580b2762696Bf9F6e9149884d54e8150a19 // WBTC Aggregator
            )
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(
                0xE6DFbEE9D497f1b851915166E26A273cB03F27E1, // USDC
                0x06322002130c5Fd3a5715F28f46EC28fa99584bE, // WETH
                0x6A285E46Fce971CC762653EE9b8F81207A45214E, // USDC Aggregator
                0x373472E12Da7e185576D5A07d52BcAD25690a08a // WETH Aggregator
            )
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(
                0xc0233309cD5e1fa340E2b681Dba3D4240aB6F49d, // USDT
                0x06322002130c5Fd3a5715F28f46EC28fa99584bE, // WETH
                0xB6D68C67BCA08023d2C51C9B487515A20Cc2bc2E, // USDT Aggregator
                0x373472E12Da7e185576D5A07d52BcAD25690a08a // WETH Aggregator
            )
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(
                0x51a439096Ee300eC7a07FFd7Fa55a1f8723948c5, // DAI
                0x472A3ec37E662b295fd25E3b5d805117345a89D1, // WBTC
                0x1a4EaA946b1105f16DB9b3a9b7e119fc15e70E4c, // DAI Aggregator
                0x32423580b2762696Bf9F6e9149884d54e8150a19 // WBTC Aggregator
            )
        );
        lendingPoolSeeds.push(
            LendingPoolConfig(
                0x51a439096Ee300eC7a07FFd7Fa55a1f8723948c5, // DAI
                0x06322002130c5Fd3a5715F28f46EC28fa99584bE, // WETH
                0x1a4EaA946b1105f16DB9b3a9b7e119fc15e70E4c, // DAI Aggregator
                0x373472E12Da7e185576D5A07d52BcAD25690a08a // WETH Aggregator
            )
        );

        for (uint256 i = 0; i < lendingPoolSeeds.length; i++) {
            LendingPoolConfig memory lendingPool = lendingPoolSeeds[i];
            address lendingPoolAddr = lendingPoolFactory.createLendingPool(
                lendingPool.loanToken,
                lendingPool.collateralToken,
                lendingPool.loanTokenPriceFeed,
                lendingPool.collateralTokenPriceFeed,
                80,
                5,
                PositionType.LONG
            );

            address loanToken = ILendingPool(lendingPoolAddr).loanToken();
            console.log("Lending Pool deployed at:", lendingPoolAddr);

            MockERC20(loanToken).mint(address(this), supplyAmount);
            MockERC20(loanToken).approve(lendingPoolAddr, supplyAmount);
            ILendingPool(lendingPoolAddr).supply(supplyAmount);
        }

        vm.stopBroadcast();
    }

    function run() external {
        createBulkLendingPools();
    }
}
