// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {LendingPool} from "./LendingPool.sol";

struct BasePoolParams {
    address loanToken;
    address collateralToken;
    address loanTokenUsdDataFeed;
    address collateralTokenUsdDataFeed;
}

struct PoolParams {
    BasePoolParams basePoolParams;
    address lendingPool;
}

contract LendingPoolFactory {
    error PoolAlreadyCreated();

    mapping(bytes32 => PoolParams) public lendingPools;

    event AllLendingPool(
        string loanTokenName,
        string collateralTokenName,
        string loanTokenSymbol,
        string collateralTokenSymbol,
        address loanToken,
        address collateralToken,
        address loanTokenUsdDataFeed,
        address collateralTokenUsdDataFeed,
        address lendingPool,
        uint256 timestamp
    );

    function createLendingPool(BasePoolParams memory params) external {
        bytes32 id = keccak256(abi.encode(params.loanToken, params.collateralToken));
        if (lendingPools[id].lendingPool != address(0)) revert PoolAlreadyCreated();

        LendingPool lendingPool = new LendingPool(
            IERC20(params.loanToken),
            IERC20(params.collateralToken),
            AggregatorV2V3Interface(params.loanTokenUsdDataFeed),
            AggregatorV2V3Interface(params.collateralTokenUsdDataFeed)
        );
        lendingPools[id] = PoolParams(params, address(lendingPool));

        emit AllLendingPool(
            getTokenName(params.loanToken),
            getTokenName(params.collateralToken),
            getTokenSymbol(params.loanToken),
            getTokenSymbol(params.collateralToken),
            params.loanToken,
            params.collateralToken,
            params.loanTokenUsdDataFeed,
            params.collateralTokenUsdDataFeed,
            address(lendingPool),
            block.timestamp
        );
    }

    function getTokenName(address token) internal view returns (string memory) {
        try ERC20(token).name() returns (string memory tokenName) {
            return tokenName;
        } catch {
            return "Unknown"; // Fallback name if `name()` is not implemented
        }
    }

    function getTokenSymbol(address token) internal view returns (string memory) {
        try ERC20(token).symbol() returns (string memory tokenSymbol) {
            return tokenSymbol;
        } catch {
            return "UNKNOWN"; // Fallback name if `symbol()` is not implemented
        }
    }
}
