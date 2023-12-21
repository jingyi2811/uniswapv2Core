pragma solidity >=0.5.0;

interface IUniswapV2Pool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);
}