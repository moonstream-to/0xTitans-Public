// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ICar.sol";

contract DummyCar is ICar {
    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata /*bananas*/,
        uint256 ourCarIndex
    ) external override {
        Monaco.CarData memory ourCar = allCars[ourCarIndex];
        if (ourCar.balance > monaco.getAccelerateCost(1))
            ourCar.balance -= uint24(monaco.buyAcceleration(1));
    }

    function sayMyName() external pure returns (string memory) {
        return "DummyCar";
    }
}
