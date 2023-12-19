// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../src/IUniswapV2Factory.sol';
import '../src/IUniswapV2Pair.sol';

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract PoolTest is Test {
    address daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address factoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IUniswapV2Factory factory;
    IUniswapV2Pair pair;

    function setUp() public {
        factory = IUniswapV2Factory(factoryAddress);
        pair = IUniswapV2Pair(factory.getPair(daiAddress, usdtAddress));
    }

    function testStablePool() public {
        (uint112 x, uint112 y, )= pair.getReserves();
        console.log(x);
        console.log(y);
    }
}