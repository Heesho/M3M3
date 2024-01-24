// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMemeFactory {
    function getMemeCount() external view returns (uint256);
    function getMemeByIndex(uint256 index) external view returns (address);
    function getIndexByMeme(address meme) external view returns (uint256);
    function getIndexBySymbol(string memory symbol) external view returns (uint256);
}

interface IPreMeme {
    function totalBaseContributed() external view returns (uint256);
    function totalMemeBalance() external view returns (uint256);
    function ended() external view returns (bool);
    function endTimestamp() external view returns (uint256);
    function account_BaseContributed(address account) external view returns (uint256);
}

interface IMeme {
    function preMeme() external view returns (address);
    function uri() external view returns (string memory);
    function status() external view returns (string memory);
    function statusHolder() external view returns (address);
    function reserveBase() external view returns (uint256);
    function RESERVE_VIRTUAL_BASE() external view returns (uint256);
    function reserveMeme() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    function getMarketPrice() external view returns (uint256);
    function getFloorPrice() external view returns (uint256);
    function claimableBase(address account) external view returns (uint256);
    function totalFeesBase() external view returns (uint256);
}

interface IChainlinkOracle {
    function latestAnswer() external view returns (uint256);
}

contract MemeMulticall {

    /*----------  CONSTANTS  --------------------------------------------*/

    address public constant ORACLE = 0x0000000000000000000000000000000000000000;
    uint256 public constant FEE = 100;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant PRECISION = 1e18;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable memeFactory;   
    address public immutable base;

    struct MemeData {
        address meme;
        string name;
        string symbol;

        string uri;
        string status;

        bool marketOpen;
        uint256 marketOpenTimestamp;
        uint256 baseContributed;
        
        uint256 maxSupply;
        uint256 price;
        address statusHolder;

        uint256 accountContributed;
        uint256 accountRedeemable;
        uint256 accountNative;
        uint256 accountBalance;
        uint256 accountClaimableBase;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(address _memeFactory, address _base) {
        memeFactory = _memeFactory;
        base = _base;
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getBasePrice() public view returns (uint256) {
        if (ORACLE == address(0)) return 1e18;
        return IChainlinkOracle(ORACLE).latestAnswer() * 1e18 / 1e8;
    }

    function getMemeCount() external view returns (uint256) {
        return IMemeFactory(memeFactory).getMemeCount();
    }

    function getIndexByMeme(address meme) external view returns (uint256) {
        return IMemeFactory(memeFactory).getIndexByMeme(meme);
    }

    function getMemeByIndex(uint256 index) external view returns (address) {
        return IMemeFactory(memeFactory).getMemeByIndex(index);
    }

    function getIndexBySymbol(string memory symbol) external view returns (uint256) {
        return IMemeFactory(memeFactory).getIndexBySymbol(symbol);
    }

    function getMemeData(uint256 index, address account) public view returns (MemeData memory memeData) {
        memeData.meme = IMemeFactory(memeFactory).getMemeByIndex(index);
        memeData.name = IERC20Metadata(memeData.meme).name();
        memeData.symbol = IERC20Metadata(memeData.meme).symbol();

        memeData.uri = IMeme(memeData.meme).uri();
        memeData.status = IMeme(memeData.meme).status();

        address preMeme = IMeme(memeData.meme).preMeme();
        memeData.marketOpen = !IPreMeme(preMeme).ended();
        memeData.marketOpenTimestamp = IPreMeme(preMeme).endTimestamp();
        memeData.baseContributed = IPreMeme(preMeme).totalBaseContributed();
        uint256 fee = memeData.baseContributed * FEE / DIVISOR;

        uint256 newReserveBase = IMeme(memeData.meme).reserveBase() + IMeme(memeData.meme).RESERVE_VIRTUAL_BASE() + memeData.baseContributed - fee;
        uint256 newReserveMeme = (IMeme(memeData.meme).reserveBase() + IMeme(memeData.meme).RESERVE_VIRTUAL_BASE()) * IMeme(memeData.meme).reserveMeme() / newReserveBase;
        uint256 expectedMemeAmount = IMeme(memeData.meme).reserveMeme() - newReserveMeme;

        memeData.maxSupply = IMeme(memeData.meme).maxSupply();
        memeData.price = (memeData.marketOpen ? IMeme(memeData.meme).getMarketPrice() * getBasePrice() / 1e18 : memeData.baseContributed * getBasePrice() / expectedMemeAmount);
        memeData.statusHolder = IMeme(memeData.meme).statusHolder();

        memeData.accountContributed = IPreMeme(preMeme).account_BaseContributed(account);
        memeData.accountRedeemable = (memeData.marketOpen ? IPreMeme(preMeme).totalMemeBalance() * memeData.accountContributed / memeData.baseContributed : expectedMemeAmount * memeData.accountContributed / memeData.baseContributed);
        memeData.accountNative = account.balance;
        memeData.accountBalance = IERC20(memeData.meme).balanceOf(account);
        memeData.accountClaimableBase = IMeme(memeData.meme).claimableBase(account);

    }

    function getMemeDataArray(uint256[] memory indexes, address account) external view returns (MemeData[] memory memeDatas) {
        memeDatas = new MemeData[](indexes.length);
        for (uint256 i = 0; i < indexes.length; i++) {
            memeDatas[i] = getMemeData(indexes[i], account);
        }
    }

    function getMemeDataIndexes(uint256 start, uint256 end, address account) external view returns (MemeData[] memory memeDatas) {
        memeDatas = new MemeData[](end - start);
        for (uint256 i = start; i < end; i++) {
            memeDatas[i - start] = getMemeData(i, account);
        }
    }
    
    function quoteBuyIn(address meme, uint256 input, uint256 slippageTolerance) external view returns(uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 fee = input * FEE / DIVISOR;
        uint256 newReserveBase = IMeme(meme).reserveBase() + IMeme(meme).RESERVE_VIRTUAL_BASE() + input - fee;
        uint256 newReserveMeme = (IMeme(meme).reserveBase() + IMeme(meme).RESERVE_VIRTUAL_BASE()) * IMeme(meme).reserveMeme() / newReserveBase;

        output = IMeme(meme).reserveMeme() - newReserveMeme;
        slippage = 100 * (1e18 - (output * IMeme(meme).getMarketPrice() / input));
        minOutput = (input * 1e18 / IMeme(meme).getMarketPrice()) * slippageTolerance / DIVISOR;
        autoMinOutput = (input * 1e18 / IMeme(meme).getMarketPrice()) * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteBuyOut(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 oldReserveBase = IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase();

        output = DIVISOR * ((oldReserveBase * IMeme(meme).reserveMeme() / (IMeme(meme).reserveMeme() - input)) - oldReserveBase) / (DIVISOR - FEE);
        slippage = 100 * (1e18 - (input * IMeme(meme).getMarketPrice() / output));
        minOutput = input * slippageTolerance / DIVISOR;
        autoMinOutput = input * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteSellIn(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 fee = input * FEE / DIVISOR;
        uint256 newReserveMeme = IMeme(meme).reserveMeme() + input - fee;
        uint256 newReserveBase = (IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase()) * IMeme(meme).reserveMeme() / newReserveMeme;

        output = (IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase()) - newReserveBase;
        slippage = 100 * (1e18 - (output * 1e18 / (input * IMeme(meme).getMarketPrice() / 1e18)));
        minOutput = input * IMeme(meme).getMarketPrice() /1e18 * slippageTolerance / DIVISOR;
        autoMinOutput = input * IMeme(meme).getMarketPrice() /1e18 * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

    function quoteSellOut(address meme, uint256 input, uint256 slippageTolerance) external view returns (uint256 output, uint256 slippage, uint256 minOutput, uint256 autoMinOutput) {
        uint256 oldReserveBase = IMeme(meme).RESERVE_VIRTUAL_BASE() + IMeme(meme).reserveBase();
        
        output = DIVISOR * ((oldReserveBase * IMeme(meme).reserveMeme()  / (oldReserveBase - input)) - IMeme(meme).reserveMeme()) / (DIVISOR - FEE);
        slippage = 100 * (1e18 - (input * 1e18 / (output * IMeme(meme).getMarketPrice() / 1e18)));
        minOutput = input * slippageTolerance / DIVISOR;
        autoMinOutput = input * ((DIVISOR * 1e18) - ((slippage + 1e18) * 100)) / (DIVISOR * 1e18);
    }

}