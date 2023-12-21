// @audit

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "v3-core/contracts/libraries/FullMath.sol";
import {FixedPointMathLib} from "lib/solmate/src/utils/FixedPointMathLib.sol";
import "forge-std/console.sol";

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

contract UniswapV2PoolTokenPrice {
    using FullMath for uint256;

    uint8 internal constant MAX_DECIMALS = 26;
    uint256 internal constant BALANCES_COUNT = 2;

    struct UniswapV2PoolParams {
        IUniswapV2Pool pool;
    }

    error UniswapV2_AssetDecimalsOutOfBounds(
        address asset_,
        uint8 assetDecimals_,
        uint8 maxDecimals_
    );

    error UniswapV2_LookupTokenNotFound(address pool_, address asset_);
    error UniswapV2_OutputDecimalsOutOfBounds(uint8 outputDecimals_, uint8 maxDecimals_);
    error UniswapV2_PoolTokenBalanceInvalid(address pool_, uint8 balanceIndex_, uint256 balance_);
    error UniswapV2_PoolBalancesInvalid(
        address pool_,
        uint256 balanceCount_,
        uint256 expectedBalanceCount_
    );
    error UniswapV2_ParamsPoolInvalid(uint8 paramsIndex_, address pool_);
    error UniswapV2_PoolSupplyInvalid(address pool_, uint256 supply_);
    error UniswapV2_PoolTokensInvalid(address pool_, uint256 tokenIndex_, address token_);
    error UniswapV2_PoolTypeInvalid(address pool_);

    function _getTokens(IUniswapV2Pool pool_) internal view returns (address[] memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = pool_.token0();
        tokens[1] = pool_.token1();

        return tokens;
    }

    function _getReserves(IUniswapV2Pool pool_) internal view returns (uint112[] memory) {
        try pool_.getReserves() returns (uint112 token0Reserves, uint112 token1Reserves, uint32) {
            uint112[] memory balances = new uint112[](2);
            balances[0] = token0Reserves;
            balances[1] = token1Reserves;

            return balances;
        } catch (bytes memory) {
            revert UniswapV2_PoolTypeInvalid(address(pool_));
        }
    }

    function _convertERC20Decimals(
        uint112 value_,
        address token_,
        uint8 outputDecimals_
    ) internal view returns (uint256) {
        uint8 tokenDecimals = ERC20(token_).decimals();
        if (tokenDecimals > MAX_DECIMALS)
            revert UniswapV2_AssetDecimalsOutOfBounds(token_, tokenDecimals, MAX_DECIMALS);

        return (uint256(value_)).mulDiv(10 ** outputDecimals_, 10 ** tokenDecimals);
    }

    function getPoolTokenPrice(
        address,
        uint8 outputDecimals_,
        bytes calldata params_
    ) external view returns (uint256) {

        // Prevent overflow
        if (outputDecimals_ > MAX_DECIMALS)
            revert UniswapV2_OutputDecimalsOutOfBounds(outputDecimals_, MAX_DECIMALS);

        address token0;
        address token1;
        uint256 k; // outputDecimals_
        uint256 poolSupply; // outputDecimals_
        {
            IUniswapV2Pool pool;
            {
                // Decode params
                UniswapV2PoolParams memory params = abi.decode(params_, (UniswapV2PoolParams));
                if (address(params.pool) == address(0))
                    revert UniswapV2_ParamsPoolInvalid(0, address(params.pool));

                pool = IUniswapV2Pool(params.pool);
            }

            // Get balances
            // Call this first as it will check on whether the pool is valid, and exit
            uint112[] memory balances = _getReserves(pool);
            if (balances.length < BALANCES_COUNT)
                revert UniswapV2_PoolBalancesInvalid(
                    address(pool),
                    balances.length,
                    BALANCES_COUNT
                );

            // Get tokens
            token0 = pool.token0();
            token1 = pool.token1();
            if (token0 == address(0)) revert UniswapV2_PoolTokensInvalid(address(pool), 0, token0);
            if (token1 == address(0)) revert UniswapV2_PoolTokensInvalid(address(pool), 1, token1);

            // Convert balances to outputDecimals_
            uint256 balance0;
            {
                uint8 token0Decimals = ERC20(token0).decimals();
                if (token0Decimals > MAX_DECIMALS)
                    revert UniswapV2_AssetDecimalsOutOfBounds(token0, token0Decimals, MAX_DECIMALS);

                balance0 = uint256(balances[0]).mulDiv(10 ** outputDecimals_, 10 ** token0Decimals);

                console.log('balance0 = ', balance0);
            }

            uint256 balance1;
            {
                uint8 token1Decimals = ERC20(token1).decimals();
                if (token1Decimals > MAX_DECIMALS)
                    revert UniswapV2_AssetDecimalsOutOfBounds(token1, token1Decimals, MAX_DECIMALS);

                balance1 = uint256(balances[1]).mulDiv(10 ** outputDecimals_, 10 ** token1Decimals);

                console.log('balance1 = ', balance0);
            }

            if (balance0 == 0) revert UniswapV2_PoolTokenBalanceInvalid(address(pool), 0, balance0);
            if (balance1 == 0) revert UniswapV2_PoolTokenBalanceInvalid(address(pool), 1, balance1);

            // Determine balance0 * balance1 = k
            k = balance0.mulDiv(balance1, 10 ** outputDecimals_);

            uint256 poolSupply_ = pool.totalSupply();
            if (poolSupply_ == 0) revert UniswapV2_PoolSupplyInvalid(address(pool), poolSupply_);

            // Shift the pool supply into outputDecimals_
            uint8 poolDecimals = pool.decimals(); // Always 18
            poolSupply = poolSupply_.mulDiv(10 ** outputDecimals_, 10 ** poolDecimals);

            console.log('poolSupply = ', poolSupply);
        }

        uint256 price0; // outputDecimals_
        uint256 price1; // outputDecimals_
        {
            uint256 price0_ = 1e18;
            uint256 price1_ = 1e18;

            price0 = price0_;
            price1 = price1_;
        }

        uint256 poolValue; // outputDecimals_
        {
            uint256 priceMultiple = FixedPointMathLib.sqrt(
                price0.mulDiv(price1, 10 ** outputDecimals_) * k
            ); // sqrt(price * price) = outputDecimals_

            uint256 two = 2 * 10 ** outputDecimals_;
            poolValue = two.mulDiv(priceMultiple, poolSupply);

            console.log('poolValue = ', poolValue);
        }

        return poolValue;
    }

    function getPoolTokenPrice1(
        address,
        uint8 outputDecimals_,
        bytes calldata params_
    ) external view returns (uint256) {

        // Prevent overflow
        if (outputDecimals_ > MAX_DECIMALS)
            revert UniswapV2_OutputDecimalsOutOfBounds(outputDecimals_, MAX_DECIMALS);

        address token0;
        address token1;
        uint256 k; // outputDecimals_
        uint256 poolSupply; // outputDecimals_
        {
            IUniswapV2Pool pool;
            {
                // Decode params
                UniswapV2PoolParams memory params = abi.decode(params_, (UniswapV2PoolParams));
                if (address(params.pool) == address(0))
                    revert UniswapV2_ParamsPoolInvalid(0, address(params.pool));

                pool = IUniswapV2Pool(params.pool);
            }

            // Get balances
            // Call this first as it will check on whether the pool is valid, and exit
            uint112[] memory balances = _getReserves(pool);
            if (balances.length < BALANCES_COUNT)
                revert UniswapV2_PoolBalancesInvalid(
                    address(pool),
                    balances.length,
                    BALANCES_COUNT
                );

            // Get tokens
            token0 = pool.token0();
            token1 = pool.token1();
            if (token0 == address(0)) revert UniswapV2_PoolTokensInvalid(address(pool), 0, token0);
            if (token1 == address(0)) revert UniswapV2_PoolTokensInvalid(address(pool), 1, token1);

            // Convert balances to outputDecimals_
            uint256 balance0;
            {
                uint8 token0Decimals = ERC20(token0).decimals();
                if (token0Decimals > MAX_DECIMALS)
                    revert UniswapV2_AssetDecimalsOutOfBounds(token0, token0Decimals, MAX_DECIMALS);

                balance0 = balances[0];

                console.log('balance0 = ', balance0);
            }

            uint256 balance1;
            {
                uint8 token1Decimals = ERC20(token1).decimals();
                if (token1Decimals > MAX_DECIMALS)
                    revert UniswapV2_AssetDecimalsOutOfBounds(token1, token1Decimals, MAX_DECIMALS);

                balance1 = balances[1];

                console.log('balance1 = ', balance0);
            }

            if (balance0 == 0) revert UniswapV2_PoolTokenBalanceInvalid(address(pool), 0, balance0);
            if (balance1 == 0) revert UniswapV2_PoolTokenBalanceInvalid(address(pool), 1, balance1);

            // Determine balance0 * balance1 = k
            k = balance0.mulDiv(balance1, 10 ** outputDecimals_);

            uint256 poolSupply_ = pool.totalSupply();
            if (poolSupply_ == 0) revert UniswapV2_PoolSupplyInvalid(address(pool), poolSupply_);

            // Shift the pool supply into outputDecimals_
            uint8 poolDecimals = pool.decimals(); // Always 18
            poolSupply = poolSupply_;

            console.log('poolSupply = ', poolSupply);
        }

        uint256 price0; // outputDecimals_
        uint256 price1; // outputDecimals_
        {
            uint256 price0_ = 1e18;
            uint256 price1_ = 1e18;

            price0 = price0_;
            price1 = price1_;
        }

        uint256 poolValue; // outputDecimals_
        {
            uint256 priceMultiple = FixedPointMathLib.sqrt(
                price0 * price1 * k
            ); // sqrt(price * price) = outputDecimals_

            uint256 two = 2 * 10 ** outputDecimals_;
            poolValue = two.mulDiv(priceMultiple, poolSupply);

            uint newPoolValue = poolValue.mulDiv(10 ** outputDecimals_, 10 ** 18);

            console.log('poolValue = ', newPoolValue);
        }

        return poolValue;
    }

    function getTokenPrice(
        address lookupToken_,
        uint8 outputDecimals_,
        bytes calldata params_
    ) external view returns (uint256) {
        // Prevent overflow
        if (outputDecimals_ > MAX_DECIMALS)
            revert UniswapV2_OutputDecimalsOutOfBounds(outputDecimals_, MAX_DECIMALS);

        // Decode params
        IUniswapV2Pool pool;
        {
            UniswapV2PoolParams memory params = abi.decode(params_, (UniswapV2PoolParams));
            if (address(params.pool) == address(0))
                revert UniswapV2_ParamsPoolInvalid(0, address(params.pool));

            pool = IUniswapV2Pool(params.pool);
        }

        uint112[] memory balances_;
        address[] memory tokens_;
        {
            uint112[] memory balances = _getReserves(pool);
            if (balances.length < BALANCES_COUNT)
                revert UniswapV2_PoolBalancesInvalid(
                    address(pool),
                    balances.length,
                    BALANCES_COUNT
                );

            balances_ = balances;
            tokens_ = _getTokens(pool);
        }

        uint256 lookupTokenIndex = type(uint256).max;
        uint256 destinationTokenIndex = type(uint256).max;
        uint256 destinationTokenPrice; // Scale: outputDecimals_
        {
            address token0 = tokens_[0];
            address token1 = tokens_[1];

            if (token0 == address(0)) revert UniswapV2_PoolTokensInvalid(address(pool), 0, token0);
            if (token1 == address(0))
                revert UniswapV2_PoolTokensInvalid(address(pool), 1, tokens_[1]);
            if (lookupToken_ != token0 && lookupToken_ != token1)
                revert UniswapV2_LookupTokenNotFound(address(pool), lookupToken_);

            lookupTokenIndex = (lookupToken_ == token0) ? 0 : 1;
            destinationTokenIndex = 1 - lookupTokenIndex;

            uint256 destinationTokenPrice_ = 1e18;
            destinationTokenPrice = destinationTokenPrice_;
        }

        // Calculate the rate of the lookup token
        uint256 lookupTokenUsdPrice;
        {
            uint256 lookupTokenBalance = _convertERC20Decimals(
                balances_[lookupTokenIndex],
                tokens_[lookupTokenIndex],
                outputDecimals_
            );
            uint256 destinationTokenBalance = _convertERC20Decimals(
                balances_[destinationTokenIndex],
                tokens_[destinationTokenIndex],
                outputDecimals_
            );

            // Get the lookupToken in terms of the destinationToken
            lookupTokenUsdPrice = destinationTokenBalance.mulDiv(
                destinationTokenPrice,
                lookupTokenBalance
            );
        }

        return lookupTokenUsdPrice;
    }
}