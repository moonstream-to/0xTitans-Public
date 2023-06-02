// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./../../interfaces/ICar.sol";

contract MoonstreamQuotaCar is ICar {
    uint256 internal constant SHELL_MAX = 200;
    uint256 internal constant SUPER_SHELL_MAX = 300;
    uint256 internal constant SHIELD_MAX = 100;
    uint256 internal constant BANANA_MAX = 100;

    uint256 internal constant PER_TURN_SPEND = 350;

    function takeYourTurn(
        Monaco monaco,
        Monaco.CarData[] calldata /*allCars*/,
        uint256[] calldata /*bananas*/,
        uint256 ourCarIndex
    ) external {
        uint256 spent = 0;
        if (ourCarIndex != 0 && monaco.getSuperShellCost(1) < SUPER_SHELL_MAX) {
            spent += monaco.buySuperShell(1);
        }
        if (
            ourCarIndex != 2 &&
            monaco.getBananaCost() < BANANA_MAX &&
            spent < PER_TURN_SPEND
        ) {
            spent += monaco.buyBanana();
        }
        if (
            ourCarIndex != 0 &&
            monaco.getShellCost(1) < SHELL_MAX &&
            spent < PER_TURN_SPEND
        ) {
            spent += monaco.buyShell(1);
        }
        if (
            ourCarIndex != 2 &&
            monaco.getShieldCost(1) < SHIELD_MAX &&
            spent < PER_TURN_SPEND
        ) {
            spent += monaco.buyShield(1);
        }
        while (spent < PER_TURN_SPEND) {
            spent += monaco.buyAcceleration(1);
        }
    }

    function sayMyName() external pure returns (string memory) {
        return "MoonstreamQuotaCar";
    }
}
