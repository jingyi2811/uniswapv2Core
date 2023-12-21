// https://www.coingecko.com/en/exchanges/uniswap-v2-ethereum

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../src/IUniswapV2Factory.sol';
import '../src/IUniswapV2Pair.sol';
import '../src/IERC20.sol';

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/pool.sol";

contract PoolTest is Test {
    address firstAddress = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address secondAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address factoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    IUniswapV2Factory factory;
    IUniswapV2Pair pair;
    IUniswapV2Pool pool;

    function setUp() public {
        factory = IUniswapV2Factory(factoryAddress);
        pair = IUniswapV2Pair(factory.getPair(firstAddress, secondAddress));
        pool = IUniswapV2Pool(address(pair));
    }

    function testPoolTokenPrices() public {
        bytes memory encoded = abi.encode(pool);

        UniswapV2PoolTokenPrice u = new UniswapV2PoolTokenPrice();
        u.getPoolTokenPrice(address(0), 18, encoded);
        u.getPoolTokenPrice1(address(0), 18, encoded);
    }

    function testGetTokenPrice() public {

        (uint balance1, uint balance2, ) = pool.getReserves();

        console.log(balance1);
        console.log(balance2);
        bytes memory encoded = abi.encode(pool);

        UniswapV2PoolTokenPrice u = new UniswapV2PoolTokenPrice();

        uint firstPrice = u.getTokenPrice(firstAddress, 18, encoded);
        uint secondPrice = u.getTokenPrice(secondAddress, 18, encoded);

        console.log(IERC20(firstAddress).symbol(), '=' , firstPrice);
        console.log(IERC20(secondAddress).symbol(), '=', secondPrice);
//
//        console.log(IERC20(firstAddress).symbol(), ' price =' , firstPrice * 10 ** 18 / secondPrice);
//        console.log(IERC20(secondAddress).symbol(), ' price =', secondPrice * 10 ** 18 / firstPrice);

        console.log(u.getMyFirstPrice(address(pair), 1e18));
        console.log(u.getMySecondPrice(address(pair), 1e18));
    }
}