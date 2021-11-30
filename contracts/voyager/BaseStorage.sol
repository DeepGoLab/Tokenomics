// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BaseStorage {
    struct FeeComponent {
        uint256 dgt;
        uint256 dsp;
    }

    struct Voyager {
        uint8 level;
        uint256 id;
        address minter;
        uint256 startHoldingTime; 
        uint256 levelStartHoldingTime; 
    }

    /*** CONSTANTS ***/
    uint32[5] public cooldowns = [
        uint32(30 minutes),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    uint256 public minLevel = 1;   
    uint256 public initialSupply = 1000;
    uint public decimals = 10 ** 18;
    uint[6] public levelUpDGT = [100, 100, 100, 300, 1000, 1000];
    uint[6] public levelUpDSP = [3593, 3683, 3808, 7457, 11230, 18686];
    uint256[6] public levelUpDSPParam1 = [3621, 3972, 4097, 7763, 11553, 19044]; 
    uint256[6] public levelUpDSPParam2 = [3621, 3668, 3793, 7459, 11249, 18740]; 

    /*** STORAGE ***/
    FeeComponent[] public levelUpFees;

    uint256 public maxLevel;

    address public dgtAddress;
    address public dspAddress;
}
