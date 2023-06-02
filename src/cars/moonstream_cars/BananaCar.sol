// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ICar.sol";

contract BananaCar is ICar {
    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata /*bananas*/,
        uint256 ourCarIndex
    ) external override {
        Monaco.CarData memory ourCar = allCars[ourCarIndex];
        // If we can afford to accelerate 3 times, let's do it.
        if (ourCar.balance > monaco.getAccelerateCost(3))
            ourCar.balance -= uint24(monaco.buyAcceleration(3));

        if (ourCar.speed > 5) {
            monaco.buyBanana();
        }
    }

    function hasEnoughBalance(
        Monaco.CarData memory ourCar,
        uint256 cost
    ) internal pure returns (bool) {
        return ourCar.balance > cost;
    }

    function sayMyName() external pure returns (string memory) {
        return "BananaCar";
    }
}
