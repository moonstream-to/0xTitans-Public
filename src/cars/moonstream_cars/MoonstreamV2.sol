// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ICar.sol";
import "../../utils/SignedWadMath.sol";

contract MoonstreamV2 is ICar {
    struct Cars {
        Monaco.CarData[] allCars;
        Monaco.CarData ourCar;
        uint256 ourCarIndex;
        Monaco.CarData leadCar;
        Monaco.CarData lagCar;
    }

    struct Costs {
        uint256 accelCost;
        uint256 shellCost;
        uint256 superCost;
        uint256 bananaCost;
        uint256 shieldCost;
    }

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
        Cars memory cars,
        uint256[] memory bananas
    ) internal pure returns (uint256 effectiveness) {
        effectiveness = 1;
        if (cars.ourCarIndex != 0) {
            bool bananaInTheWay = false;
            for (uint i = 0; i < bananas.length; ++i) {
                // skip bananas that are behind or on us
                if (bananas[i] <= cars.ourCar.y) continue;

                // Check if the closest car is closer than the closest banana
                // If a banana is on top of the closest car, the banana is hit
                if (bananas[i] <= cars.leadCar.y) {
                    effectiveness = (cars.ourCar.speed / 4);
                    bananaInTheWay = true;
                    break;
                }
            }

            if (!bananaInTheWay) {
                // lead metrics -- data about the car in front
                uint256 leadSpeedDelta = cars.leadCar.speed - cars.ourCar.speed;
                uint256 leadDistance = cars.leadCar.y - cars.ourCar.y;
                if (cars.leadCar.shield == 0 && leadDistance > 0) {
                    if (leadSpeedDelta > 0) {
                        effectiveness = 3;
                    } else {
                        effectiveness = 2;
                    }
                    effectiveness += cars.leadCar.speed / 4;
                }
            }
        }
    }

    function isShellEfficient(
        uint256 shellCost,
        uint256 shellEffectiveness,
        int256 scalerWad
    ) internal pure returns (bool) {
        uint256 efficiencyCost = shellEffectiveness * 50;
        return shellCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getBananaEffectiveness(
        Cars memory cars
    ) internal pure returns (uint256 effectiveness) {
        effectiveness = 1;

        if (cars.ourCarIndex == 0) {
            // lag metrics -- data about the car behind
            uint256 lagDistance = cars.ourCar.y - cars.lagCar.y;
            uint256 lagSpeedDelta = cars.ourCar.speed - cars.lagCar.speed;

            if (lagSpeedDelta > 0) {
                effectiveness = 2;
            } else {
                effectiveness = 3;
            }
            effectiveness += (cars.lagCar.speed / 5);
        }
    }

    function isBananaEfficient(
        uint256 bananaCost,
        uint256 bananaEffectiveness,
        int256 scalerWad
    ) internal pure returns (bool) {
        uint256 efficiencyCost = bananaEffectiveness * 20;
        return bananaCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getSuperEffectiveness(
        Cars memory cars,
        uint256[] memory bananas
    ) internal pure returns (uint256 effectiveness) {
        effectiveness = 1;
        if (cars.ourCarIndex != 0 && cars.allCars[0].y > cars.ourCar.y) {
            effectiveness++;
            uint256 totalSpeed = cars.allCars[0].speed;
            if (cars.ourCarIndex == 2 && cars.allCars[1].y > cars.ourCar.y) {
                totalSpeed += cars.allCars[1].speed;
            }

            effectiveness += (totalSpeed - 2) / 4;

            if (cars.leadCar.y > cars.ourCar.y) {
                for (uint i = 0; i < bananas.length; ++i) {
                    // skip bananas that are behind or on us
                    if (bananas[i] <= cars.ourCar.y) continue;

                    // Check if the closest car is closer than the closest banana
                    // If a banana is on top of the closest car, the banana is hit
                    if (bananas[i] <= cars.leadCar.y) {
                        effectiveness += cars.ourCar.speed / 2;
                    }
                }
            }
        }
    }

    function isSuperEfficient(
        uint256 superCost,
        uint256 superEffectiveness,
        int256 scalerWad
    ) internal pure returns (bool) {
        uint256 efficiencyCost = superEffectiveness * 40;
        return superCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getTurnsToLoseOptimistic(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256 ourCarIndex
    ) internal returns (uint256 turnsToLose, uint256 bestOpponentIdx) {
        turnsToLose = 1000;
        for (uint256 i = 0; i < allCars.length; i++) {
            if (i != ourCarIndex) {
                Monaco.CarData memory car = allCars[i];
                uint256 maxSpeed = car.speed +
                    maxAccel(monaco, (car.balance * 6) / 10);
                uint256 turns = maxSpeed == 0
                    ? 1000
                    : (1000 - car.y) / maxSpeed;
                if (turns < turnsToLose) {
                    turnsToLose = turns;
                    bestOpponentIdx = i;
                }
            }
        }
    }

    function maxAccel(
        Monaco monaco,
        uint256 balance
    ) internal view returns (uint256 amount) {
        uint256 current = 25;
        uint256 min = 0;
        uint256 max = 50;
        while (max - min > 1) {
            uint256 cost = monaco.getAccelerateCost(current);
            if (cost > balance) {
                max = current;
            } else if (cost < balance) {
                min = current;
            } else {
                return current;
            }
            current = (max + min) / 2;
        }
        return min;
    }

    function getSpendingScalerWad(
        uint256 turnsTaken,
        uint256 turnsToLose,
        uint256 balance,
        uint256 maxY
    ) internal pure returns (int256 scalerWad) {
        uint256 scaleFactor = 1;
        // Not sure how to scale costs.
        if (maxY > 500) {
            scaleFactor = 2;
        }
        if (maxY > 800) {
            scaleFactor = 5;
        }
        scalerWad = toWadUnsafe(scaleFactor);
    }

    function scaleTargetCost(
        uint256 targetCost,
        int256 scalerWad
    ) internal pure returns (uint256) {
        return uint256(unsafeWadMul(int256(targetCost), scalerWad));
    }

    function getMaxY(
        Monaco.CarData[] memory allCars
    ) internal pure returns (uint256 maxY) {
        maxY = 0;
        for (uint i = 0; i < allCars.length; ++i) {
            if (allCars[i].y > maxY) {
                maxY = allCars[i].y;
            }
        }
    }

    function getTargetAccelPrice(
        uint256 shellCost,
        uint256 superCost,
        int256 scalerWad
    ) internal pure returns (uint256) {
        uint256 targetAccelPrice = 20;
        uint256 averagePriceToStop = (shellCost / 20) > (superCost / 30)
            ? (superCost / 30)
            : (shellCost / 20);
        if (averagePriceToStop > targetAccelPrice) {
            targetAccelPrice = averagePriceToStop;
        }
        return scaleTargetCost(targetAccelPrice, scalerWad);
    }

    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata bananas,
        uint256 ourCarIndex
    ) external {
        Cars memory cars = Cars({
            allCars: allCars,
            ourCar: allCars[ourCarIndex],
            ourCarIndex: ourCarIndex,
            leadCar: allCars[0],
            lagCar: allCars[2]
        });

        if (ourCarIndex == 0) {
            cars.lagCar = allCars[1];
        } else if (ourCarIndex == 1) {
            cars.leadCar = allCars[0];
            cars.lagCar = allCars[2];
        } else {
            cars.leadCar = allCars[1];
        }

        Costs memory baseCosts = Costs({
            accelCost: monaco.getAccelerateCost(1),
            shellCost: monaco.getShellCost(1),
            superCost: monaco.getSuperShellCost(1),
            bananaCost: monaco.getBananaCost(),
            shieldCost: monaco.getShellCost(1)
        });

        (
            uint256 turnsToLose,
            uint256 bestOpponentIdx
        ) = getTurnsToLoseOptimistic(monaco, allCars, ourCarIndex);
        int256 spendingScalerWad = getSpendingScalerWad(
            monaco.turns(),
            turnsToLose,
            cars.ourCar.balance,
            getMaxY(allCars)
        );

        bool usedSuper = false;
        if (
            isSuperEfficient(
                baseCosts.superCost,
                getSuperEffectiveness(cars, bananas),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.superCost)
        ) {
            updateBalance(cars.ourCar, baseCosts.superCost);
            monaco.buySuperShell(1);
            usedSuper = true;
        }

        if (
            isBananaEfficient(
                baseCosts.bananaCost,
                getBananaEffectiveness(cars),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.bananaCost)
        ) {
            updateBalance(cars.ourCar, baseCosts.bananaCost);
            monaco.buyBanana();
        }

        if (
            isShellEfficient(
                baseCosts.shellCost,
                usedSuper ? 1 : getShellEffectiveness(cars, bananas),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.shellCost)
        ) {
            updateBalance(cars.ourCar, baseCosts.shellCost);
            monaco.buyShell(1);
        }

        uint256 targetAccelPrice = getTargetAccelPrice(
            monaco.getShellCost(1),
            monaco.getSuperShellCost(1),
            spendingScalerWad
        );
        while (
            monaco.getAccelerateCost(1) < targetAccelPrice &&
            hasEnoughBalance(cars.ourCar, monaco.getAccelerateCost(1))
        ) {
            updateBalance(cars.ourCar, monaco.getAccelerateCost(1));
            monaco.buyAcceleration(1);
        }
    }

    function sayMyName() external pure returns (string memory) {
        return "Moonstream v0.2.0";
    }
}
