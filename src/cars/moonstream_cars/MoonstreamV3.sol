// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ICar.sol";
import "../../utils/SignedWadMath.sol";

import {MoonstreamV2} from "./MoonstreamV2.sol";

contract MoonstreamV3 is MoonstreamV2 {
    enum CarProfile {
        Speeder,
        Spender,
        Defender
    }

    uint256 private currentTurn;
    mapping(address => mapping(CarProfile => uint256)) private profiles;
    mapping(address => uint32) private previousBalance;
    mapping(address => uint32) private previousY;

    uint32 public AVERAGE_Y_PER_TURN = 8;
    uint32 public AVERAGE_SPENT_PER_TURN = 125;

    function updateProfile(Monaco.CarData memory carData) internal virtual {
        address car = address(carData.car);
        if (carData.y - previousY[car] > 2 * AVERAGE_Y_PER_TURN) {
            profiles[car][CarProfile.Speeder] += currentTurn;
        } else if (previousBalance[car] - carData.balance > 2 * AVERAGE_SPENT_PER_TURN) {
            profiles[car][CarProfile.Spender] += currentTurn;
        } else if (carData.shield > 0) {
            profiles[car][CarProfile.Defender] += currentTurn;
        }
    }

    function currentProfile(Monaco.CarData memory carData) internal view virtual returns (CarProfile result) {
        address car = address(carData.car);
        result = CarProfile.Speeder;
        if (profiles[car][CarProfile.Spender] > profiles[car][result]) {
            result = CarProfile.Spender;
        }
        if (profiles[car][CarProfile.Defender] > profiles[car][result]) {
            result = CarProfile.Defender;
        }
    }

    function getShellEffectiveness(
        Cars memory cars,
        uint256[] memory bananas
    ) internal view override returns (uint256 effectiveness) {
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
                CarProfile leadCarProfile = currentProfile(cars.leadCar);
                if (leadCarProfile == CarProfile.Speeder) {
                    effectiveness = (3 * effectiveness) / 2;
                }
            }
        }
    }

    function getBananaEffectiveness(
        Cars memory cars
    ) internal view override returns (uint256 effectiveness) {
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
        CarProfile lagCarProfile = currentProfile(cars.lagCar);
        if (lagCarProfile != CarProfile.Spender) {
            effectiveness = 2 * effectiveness;
        }

    }

    function getSuperEffectiveness(
        Cars memory cars,
        uint256[] memory bananas
    ) internal view override returns (uint256 effectiveness) {
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

        CarProfile leadCarProfile = currentProfile(cars.leadCar);
        if (leadCarProfile == CarProfile.Spender) {
            effectiveness *= 2;
        } else if (leadCarProfile == CarProfile.Speeder) {
            effectiveness = (3 * effectiveness)/2;
        }
    }

    function sayMyName() external pure override returns (string memory) {
        return "Moonstream v0.3.0";
    }
}
