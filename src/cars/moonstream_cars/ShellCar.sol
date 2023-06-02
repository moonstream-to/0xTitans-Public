// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ICar.sol";

contract ShellCar is ICar {
    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata /*bananas*/,
        uint256 ourCarIndex
    ) external override {
        Monaco.CarData memory ourCar = allCars[ourCarIndex];
        Monaco.CarData memory leadCar;
        Monaco.CarData memory lagCar;

        if (ourCarIndex == 0) {
            lagCar = allCars[1];
        } else if (ourCarIndex == 1) {
            leadCar = allCars[0];
            lagCar = allCars[2];
        } else {
            leadCar = allCars[1];
        }

        // If we can afford to accelerate 3 times, let's do it.
        if (ourCar.balance > monaco.getAccelerateCost(2))
            ourCar.balance -= uint24(monaco.buyAcceleration(2));

        if (
            ourCarIndex != 0 &&
            allCars[ourCarIndex - 1].speed > 8 &&
            ourCar.balance > monaco.getShellCost(2)
        ) {
            // If we're not in the lead (index 0) + the car ahead of us is going faster + we can afford a shell, smoke em.
            monaco.buyShell(1); // This will instantly set the car in front of us' speed to 1.
            monaco.buyShell(1);
        }
    }

    function sayMyName() external pure returns (string memory) {
        return "ShellCar";
    }
}
