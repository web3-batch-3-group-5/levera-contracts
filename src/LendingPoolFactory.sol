// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {LendingPool} from "./LendingPool.sol";

struct BasePoolParams {
    address loanToken;
    address collateralToken;
}

struct PoolParams {
    BasePoolParams basePoolParams;
    address lendingPool;
}

contract LendingPoolFactory {
    mapping(bytes32 => PoolParams) public lendingPools;

    function createLendingPool(BasePoolParams memory params) external {
        bytes32 id = keccak256(abi.encode(params.loanToken, params.collateralToken));
        require(lendingPools[id].lendingPool == address(0), ErrorsLib.POOL_ALREADY_CREATED);

        LendingPool lendingPool = new LendingPool(IERC20(params.loanToken), IERC20(params.collateralToken));
        lendingPools[id] = PoolParams(params, address(lendingPool));
    }
}
