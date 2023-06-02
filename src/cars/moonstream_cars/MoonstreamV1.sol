// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./../../interfaces/ICar.sol";

contract MoonstreamV1 is ICar {
    function hasEnoughBalance(
        Monaco.CarData memory ourCar,
        uint256 cost
    ) internal pure returns (bool) {
        return ourCar.balance > cost;
    }

    function updateBalance(
        Monaco.CarData memory ourCar,
        uint256 cost
    ) internal pure {
        ourCar.balance -= uint24(cost);
    }

    function getShellEffectiveness(
        Monaco.CarData memory leadCar,
        Monaco.CarData memory ourCar,
        uint256 ourCarIndex
    ) internal pure returns (uint256 effectiveness) {
        effectiveness = 1;
        if (ourCarIndex != 0) {
            // lead metrics -- data about the car in front
            uint256 leadSpeedDelta = leadCar.speed - ourCar.speed;
            uint256 leadDistance = leadCar.y - ourCar.y;
            if (leadCar.shield == 0 && leadDistance > 0) {
                if (leadSpeedDelta > 0) {
                    effectiveness = 3;
                } else {
                    effectiveness = 2;
                }
            }
        }
    }

    function isShellEfficient(
        uint256 shellCost,
        uint256 shellEffectiveness
    ) internal pure returns (bool) {
        uint256 efficiencyCost = shellEffectiveness * 100;
        return shellCost < efficiencyCost;
    }

    function getBananaEffectiveness(
        Monaco.CarData memory lagCar,
        Monaco.CarData memory ourCar,
        uint256 ourCarIndex
    ) internal pure returns (uint256 effectiveness) {
        effectiveness = 1;

        if (ourCarIndex == 0) {
            // lag metrics -- data about the car behind
            uint256 lagDistance = ourCar.y - lagCar.y;
            uint256 lagSpeedDelta = ourCar.speed - lagCar.speed;

            if (lagSpeedDelta > 0) {
                effectiveness = 2;
            } else {
                effectiveness = 3;
            }
        }
    }

    function isBananaEfficient(
        uint256 bananaCost,
        uint256 bananaEffectiveness
    ) internal pure returns (bool) {
        uint256 efficiencyCost = bananaEffectiveness * 100;
        return bananaCost < efficiencyCost;
    }

    // function getSuperEffectiveness(
    //     Monaco.CarData memory leadCar,
    //     Monaco.CarData memory ourCar,
    //     uint256 ourCarIndex
    // ) internal pure returns (uint256 effectiveness) {
    //     effectiveness = 1;
    //     if (ourCarIndex != 0) {
    //         // lead metrics -- data about the car in front
    //         uint256 leadSpeedDelta = leadCar.speed - ourCar.speed;
    //         uint256 leadDistance = leadCar.y - ourCar.y;
    //         if (leadCar.shield == 0 && leadDistance > 0) {
    //             if (leadSpeedDelta > 0) {
    //                 effectiveness = 3;
    //             } else {
    //                 effectiveness = 2;
    //             }
    //         }
    //     }
    // }

    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata bananas,
        uint256 ourCarIndex
    ) external {
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

        if (
            monaco.getAccelerateCost(1) < 20 &&
            hasEnoughBalance(ourCar, monaco.getAccelerateCost(1))
        ) {
            monaco.buyAcceleration(1);
        }

        if (
            monaco.getAccelerateCost(1) < 20 &&
            hasEnoughBalance(ourCar, monaco.getAccelerateCost(1))
        ) {
            monaco.buyAcceleration(1);
        }

        uint256 bananaEffectiveness = getBananaEffectiveness(
            lagCar,
            ourCar,
            ourCarIndex
        );
        uint256 bananaCost = monaco.getBananaCost();
        if (
            isBananaEfficient(bananaCost, bananaEffectiveness) &&
            hasEnoughBalance(ourCar, bananaCost)
        ) {
            monaco.buyBanana();
        }

        uint256 shellEffectiveness = getShellEffectiveness(
            leadCar,
            ourCar,
            ourCarIndex
        );
        uint256 shellCost = monaco.getShellCost(1);
        if (
            isShellEfficient(shellCost, shellEffectiveness) &&
            hasEnoughBalance(ourCar, shellCost)
        ) {
            monaco.buyShell(1);
        }

        // while (monaco.getShellCost(1) < 75) {
        //     monaco.buyShell(1);
        // }
    }

    function sayMyName() external pure returns (string memory) {
        return "Moonstream v0.1.0";
    }
}
