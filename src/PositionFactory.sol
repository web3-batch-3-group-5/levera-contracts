// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Position} from "./Position.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import {IPosition} from "./interfaces/IPosition.sol";
import {EventLib} from "./libraries/EventLib.sol";

contract PositionFactory {
    mapping(address => mapping(address => bool)) public positions;
    mapping(address => mapping(address => address[])) public userPoolPositions; // Stores positions per user

    function createPosition(address _lendingPool, uint256 _baseCollateral, uint256 _leverage)
        external
        returns (address)
    {
        Position newPosition = new Position(_lendingPool, ILendingPool(_lendingPool).router(), msg.sender);
        address positionAddr = address(newPosition);
        address collateralToken = ILendingPool(_lendingPool).collateralToken();

        positions[msg.sender][positionAddr] = true;
        userPoolPositions[msg.sender][_lendingPool].push(positionAddr); // Store position

        ILendingPool(_lendingPool).registerPosition(positionAddr);

        require(IERC20(collateralToken).balanceOf(msg.sender) >= _baseCollateral, "Insufficient Balance");
        require(
            IERC20(collateralToken).allowance(msg.sender, address(this)) >= _baseCollateral, "Insufficient Allowance"
        );

        IERC20(collateralToken).transferFrom(msg.sender, address(this), _baseCollateral);
        IERC20(collateralToken).approve(positionAddr, _baseCollateral);

        newPosition.openPosition(_baseCollateral, _leverage);

        emit EventLib.CreatePosition(_lendingPool, msg.sender, positionAddr);
        return positionAddr;
    }

    function deletePosition(address _lendingPool, address onBehalf) external returns (address) {
        address loanToken = ILendingPool(_lendingPool).loanToken();

        uint256 withdrawAmount = IPosition(onBehalf).closePosition();
        positions[msg.sender][onBehalf] = false;

        _removeUserPosition(msg.sender, _lendingPool, onBehalf); // Remove from array

        IERC20(loanToken).approve(address(this), withdrawAmount);
        IERC20(loanToken).transfer(msg.sender, withdrawAmount);

        emit EventLib.DeletePosition(_lendingPool, msg.sender, onBehalf);
        return onBehalf;
    }

    function liquidatePosition(address _lendingPool, address onBehalf) external returns (address) {
        address loanToken = ILendingPool(_lendingPool).loanToken();

        uint256 withdrawAmount = IPosition(onBehalf).liquidatePosition();
        positions[msg.sender][onBehalf] = false;

        _removeUserPosition(msg.sender, _lendingPool, onBehalf);

        IERC20(loanToken).approve(address(this), withdrawAmount);
        IERC20(loanToken).transfer(msg.sender, withdrawAmount);

        emit EventLib.PositionDeleted(_lendingPool, msg.sender, onBehalf);
        return onBehalf;
    }

    function _removeUserPosition(address user, address _lendingPool, address position) internal {
        uint256 length = userPoolPositions[user][_lendingPool].length;
        for (uint256 i = 0; i < length; i++) {
            if (userPoolPositions[user][_lendingPool][i] == position) {
                userPoolPositions[user][_lendingPool][i] = userPoolPositions[user][_lendingPool][length - 1];
                userPoolPositions[user][_lendingPool].pop();
                break;
            }
        }
    }

    function getPoolPositions(address user, address _lendingPool) external view returns (address[] memory) {
        return userPoolPositions[user][_lendingPool];
    }
}
