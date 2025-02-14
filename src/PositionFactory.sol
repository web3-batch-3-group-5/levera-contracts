// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Position} from "./Position.sol";

interface ILendingPool {
    function borrow(uint256 amount) external;
    function supply(uint256 amount) external;
    function loanToken() external view returns (address);
    function collateralToken() external view returns (address);
    function flashLoan(address token, uint256 amount, bytes calldata data) external;
}

contract PositionFactory {
    event PositionCreated(address positionAddress, address lendingPool, address collateralToken, address loanToken);

    mapping(address => bool) public positions;

    function createPosition(address _lendingPool) external returns (address) {
        address collateralToken = ILendingPool(_lendingPool).collateralToken();
        address loanToken = ILendingPool(_lendingPool).loanToken();
        address positionAddress = address(new Position(_lendingPool, collateralToken, loanToken));

        positions[positionAddress] = true;
        emit PositionCreated(positionAddress, _lendingPool, collateralToken, loanToken);
        return positionAddress;
    }
}
