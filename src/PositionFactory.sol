// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position} from "./Position.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {EventLib} from "./libraries/EventLib.sol";

contract PositionFactory {
    mapping(address => mapping(address => bool)) public positions;
    mapping(address => address[]) public userPositions; // Stores positions per user

    function createPosition(address _lendingPool, uint256 _baseCollateral, uint256 _leverage)
        external
        returns (address)
    {
        Position newPosition = new Position(_lendingPool, ILendingPool(_lendingPool).router(), msg.sender);
        address positionAddr = address(newPosition);
        address collateralToken = ILendingPool(_lendingPool).collateralToken();

        positions[msg.sender][positionAddr] = true;
        userPositions[msg.sender].push(positionAddr); // Store position

        ILendingPool(_lendingPool).registerPosition(positionAddr);

        require(IERC20(collateralToken).balanceOf(msg.sender) >= _baseCollateral, "Insufficient Balance");
        require(
            IERC20(collateralToken).allowance(msg.sender, address(this)) >= _baseCollateral, "Insufficient Allowance"
        );

        IERC20(collateralToken).transferFrom(msg.sender, address(this), _baseCollateral);
        IERC20(collateralToken).approve(positionAddr, _baseCollateral);

        uint256 borrowAmount = newPosition.convertCollateralPrice(_baseCollateral * (_leverage - 100) / 100);
        uint256 effectiveCollateral = _baseCollateral * _leverage / 100;
        newPosition.setRiskInfo(effectiveCollateral, borrowAmount);
        newPosition.openPosition(_baseCollateral, borrowAmount);

        emit EventLib.PositionCreated(_lendingPool, msg.sender, positionAddr, _baseCollateral, _leverage);
        return positionAddr;
    }

    function deletePosition(address _lendingPool, address onBehalf) external returns (address) {
        address loanToken = ILendingPool(_lendingPool).loanToken();

        uint256 withdrawAmount = IPosition(onBehalf).closePosition();
        positions[msg.sender][onBehalf] = false;

        _removeUserPosition(msg.sender, onBehalf); // Remove from array

        IERC20(loanToken).approve(address(this), withdrawAmount);
        IERC20(loanToken).transfer(msg.sender, withdrawAmount);

        emit EventLib.PositionDeleted(_lendingPool, msg.sender, onBehalf);
        return onBehalf;
    }

    function _removeUserPosition(address user, address position) internal {
        uint256 length = userPositions[user].length;
        for (uint256 i = 0; i < length; i++) {
            if (userPositions[user][i] == position) {
                userPositions[user][i] = userPositions[user][length - 1];
                userPositions[user].pop();
                break;
            }
        }
    }

    function getUserPositions(address user) external view returns (address[] memory) {
        return userPositions[user];
    }
}
