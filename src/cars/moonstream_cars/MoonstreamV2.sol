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
    ) internal view virtual returns (uint256 effectiveness) {
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
    ) internal view virtual returns (bool) {
        uint256 efficiencyCost = shellEffectiveness * 32;
        return shellCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getBananaEffectiveness(
        Cars memory cars
    ) internal view virtual returns (uint256 effectiveness) {
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
    ) internal view virtual returns (bool) {
        uint256 efficiencyCost = bananaEffectiveness * 20;
        return bananaCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getSuperEffectiveness(
        Cars memory cars,
        uint256[] memory bananas
    ) internal view virtual returns (uint256 effectiveness) {
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
    ) internal view returns (bool) {
        uint256 efficiencyCost = superEffectiveness * 40;
        return superCost < scaleTargetCost(efficiencyCost, scalerWad);
    }

    function getShieldEffectiveness(
        Cars memory cars
    ) internal view virtual returns (uint256 effectiveness) {
        effectiveness = 1;
        if (cars.ourCarIndex != 2) {
            effectiveness += cars.ourCar.speed / 2;
        }
    }

    function isShieldEfficient(
        uint256 shieldCost,
        uint256 shieldEffectiveness,
        int256 scalarWad
    ) internal view returns (bool) {
        uint256 efficiencyCost = shieldEffectiveness * 10;
        return shieldCost < scaleTargetCost(efficiencyCost, scalarWad);
    }

    function getTurnsToLoseOptimistic(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256 ourCarIndex
    ) internal virtual returns (uint256 turnsToLose, uint256 bestOpponentIdx) {
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
        if (maxY > 600) {
            scaleFactor = 2;
        }
        if (maxY > 800) {
            scaleFactor = 4;
        }
        if (maxY > 900) {
            scaleFactor = 6;
        }
        if (maxY > 950) {
            scaleFactor = 8;
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

    // function checkForWin(
    //     Monaco monaco,
    //     Monaco.CarData memory ourCar,
    //     uint256[] memory bananas
    // ) internal returns (bool) {
    //     uint256 speedToWin = 1000 - ourCar.y;
    //     if (speedToWin <= ourCar.speed) return true;
    //     uint256 accelToWin = speedToWin - ourCar.speed;
    //     if (monaco.getAccelerateCost(accelToWin) < ourCar.balance) {
    //         monaco.buyAcceleration(accelToWin);
    //         return true;
    //     }
    //     return false;
    // }

    function accelerate(
        Monaco monaco,
        Monaco.CarData memory ourCar,
        uint256 amount
    ) internal returns (bool success) {
        if (ourCar.balance > monaco.getAccelerateCost(amount)) {
            ourCar.balance -= uint32(monaco.buyAcceleration(amount));
            return true;
        }
        return false;
    }

    function banana(
        Monaco monaco,
        Monaco.CarData memory ourCar
    ) internal returns (bool success) {
        if (ourCar.balance > monaco.getBananaCost()) {
            ourCar.balance -= uint32(monaco.buyBanana());
            return true;
        }
        return false;
    }

    function shell(
        Monaco monaco,
        Monaco.CarData memory ourCar,
        uint256 amount
    ) internal returns (bool success) {
        if (ourCar.balance > monaco.getShellCost(amount)) {
            ourCar.balance -= uint32(monaco.buyShell(amount));
            return true;
        }
        return false;
    }

    function superShell(
        Monaco monaco,
        Monaco.CarData memory ourCar,
        uint256 amount
    ) internal returns (bool success) {
        if (ourCar.balance > monaco.getSuperShellCost(amount)) {
            ourCar.balance -= uint32(monaco.buySuperShell(amount));
            return true;
        }
        return false;
    }

    function stopOpponent(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        Monaco.CarData memory ourCar,
        uint256 ourCarIdx,
        uint256 opponentIdx,
        uint256 maxCost
    ) internal {
        // in front, so use shells
        if (opponentIdx < ourCarIdx) {
            // theyre already slow so no point shelling
            if (allCars[opponentIdx].speed == 1) {
                return;
            }

            if (!superShell(monaco, ourCar, 1)) {
                // TODO: try to send enough shells to kill all bananas and the oppo
                shell(monaco, ourCar, 1);
            }
        } else if (monaco.getBananaCost() < maxCost) {
            // behind so banana
            banana(monaco, ourCar);
        }
    }

    function optimalAccelerate(
        Monaco monaco,
        Cars memory cars,
        uint256[] memory bananas,
        int256 scalarWad
    ) internal returns (int) {
        int accelToBanana = -1;
        for (uint i = 0; i < bananas.length; ++i) {
            // skip bananas that are behind or on us
            if (bananas[i] <= cars.ourCar.y) continue;

            if (bananas[i] <= cars.ourCar.y + cars.ourCar.speed) {
                // Don't accelerate if we're hitting a banana.
                accelToBanana = 0;
            } else if (bananas[i] < cars.lagCar.y + cars.lagCar.speed) {
                // Stop one step before the banana if the lag cars is going to hit it.
                accelToBanana =
                    int(bananas[i] - (cars.ourCar.y + cars.ourCar.speed)) -
                    1;
            } else {
                accelToBanana = int(
                    bananas[i] - (cars.ourCar.y + cars.ourCar.speed)
                );
            }
            break;
        }

        uint256 targetAccelPrice = getTargetAccelPrice(
            monaco.getShellCost(1),
            monaco.getSuperShellCost(1),
            scalarWad
        );

        if (accelToBanana >= 0) {
            while (
                monaco.getAccelerateCost(1) < targetAccelPrice &&
                hasEnoughBalance(cars.ourCar, monaco.getAccelerateCost(1)) &&
                (accelToBanana > 0)
            ) {
                accelerate(monaco, cars.ourCar, 1);
                accelToBanana--;
            }
        } else {
            while (
                monaco.getAccelerateCost(1) < targetAccelPrice &&
                hasEnoughBalance(cars.ourCar, monaco.getAccelerateCost(1))
            ) {
                accelerate(monaco, cars.ourCar, 1);
            }
        }
    }

    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata allCars,
        uint256[] calldata bananas,
        uint256 ourCarIndex
    ) external virtual {
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

        // if we can buy enough acceleration to win right away, do it
        uint256 accelToWin = (1000 - cars.ourCar.y) - cars.ourCar.speed;
        if (maxAccel(monaco, cars.ourCar.balance) >= accelToWin) {
            accelerate(monaco, cars.ourCar, accelToWin);
            stopOpponent(
                monaco,
                allCars,
                cars.ourCar,
                ourCarIndex,
                bestOpponentIdx,
                100000
            );
            accelerate(
                monaco,
                cars.ourCar,
                maxAccel(monaco, cars.ourCar.balance)
            );
            return;
        }

        Costs memory baseCosts = Costs({
            accelCost: monaco.getAccelerateCost(1),
            shellCost: monaco.getShellCost(1),
            superCost: monaco.getSuperShellCost(1),
            bananaCost: monaco.getBananaCost(),
            shieldCost: monaco.getShellCost(1)
        });

        bool usedSuper = false;
        if (
            isSuperEfficient(
                baseCosts.superCost,
                getSuperEffectiveness(cars, bananas),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.superCost)
        ) {
            superShell(monaco, cars.ourCar, 1);
            usedSuper = true;
        }

        if (
            isBananaEfficient(
                baseCosts.bananaCost,
                getBananaEffectiveness(cars),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.bananaCost)
        ) {
            banana(monaco, cars.ourCar);
        }

        if (
            isShellEfficient(
                baseCosts.shellCost,
                usedSuper ? 1 : getShellEffectiveness(cars, bananas),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, baseCosts.shellCost)
        ) {
            shell(monaco, cars.ourCar, 1);
        }

        optimalAccelerate(monaco, cars, bananas, spendingScalerWad);

        while (
            isShieldEfficient(
                monaco.getShieldCost(1),
                getShieldEffectiveness(cars),
                spendingScalerWad
            ) && hasEnoughBalance(cars.ourCar, monaco.getShieldCost(1))
        ) {
            updateBalance(cars.ourCar, baseCosts.shieldCost);
            monaco.buyShield(1);
        }
    }

    function sayMyName() external pure virtual returns (string memory) {
        return "Moonstream v0.2.0";
    }
}
