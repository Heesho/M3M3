// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IMemeFactory {
    function treasury() external view returns (address);
}

contract MemeFees {

    address internal immutable base;
    address internal immutable meme;

    constructor(address _base) {
        meme = msg.sender;
        base = _base;
    }

    function claimFeesFor(address recipient, uint amountBase, uint amountMeme) external {
        require(msg.sender == meme);
        if (amountBase > 0) IERC20(base).transfer(recipient, amountBase);
        if (amountMeme > 0) IERC20(meme).transfer(recipient, amountMeme);
    }

}

contract Meme is ERC20, ERC20Permit, ERC20Votes, ReentrancyGuard {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant PRECISION = 1e18;
    uint256 public constant RESERVE_VIRTUAL_BASE = 100 * PRECISION;
    uint256 public constant INITIAL_SUPPLY = 1000000 * PRECISION;
    uint256 public constant FEE = 100;
    uint256 public constant PROTOCOL_FEE = 2500;
    uint256 public constant PROVIDER_FEE = 2500;
    uint256 public constant DIVISOR = 10000;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable base;
    address public immutable fees;
    address public immutable factory;

    // bonding curve state
    uint256 public reserveBase = 0;
    uint256 public reserveMeme = INITIAL_SUPPLY;

    // fees state
    uint256 public totalFeesBase;
    uint256 public totalFeesMeme;
    uint256 public indexBase;
    uint256 public indexMeme;
    mapping(address => uint256) public supplyIndexBase;
    mapping(address => uint256) public supplyIndexMeme;
    mapping(address => uint256) public claimableBase;
    mapping(address => uint256) public claimableMeme;

    /*----------  ERRORS ------------------------------------------------*/

    error Meme__ZeroInput();
    error Meme__Expired();
    error Meme__SlippageToleranceExceeded();

    /*----------  EVENTS ------------------------------------------------*/

    event Meme__Buy(address indexed sender, address to, uint256 amountIn, uint256 amountOut);
    event Meme__Sell(address indexed sender, address to, uint256 amountIn, uint256 amountOut);
    event Meme__Fees(address indexed sender, uint256 amountBase, uint256 amountMeme);
    event Meme__Claim(address indexed sender, uint256 amountBase, uint256 amountMeme);

    /*----------  MODIFIERS  --------------------------------------------*/

    modifier notExpired(uint256 expireTimestamp) {
        if (expireTimestamp != 0 && expireTimestamp < block.timestamp) revert Meme__Expired();
        _;
    }

    modifier notZeroInput(uint256 _amount) {
        if (_amount == 0) revert Meme__ZeroInput();
        _;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(string memory _name, string memory _symbol, address _base)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        factory = msg.sender;
        base = _base;
        fees = address(new MemeFees(_base));
    }

    function buy(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        uint256 feeBase = amountIn * FEE / DIVISOR;
        uint256 newReserveBase = RESERVE_VIRTUAL_BASE + reserveBase + amountIn - feeBase;
        uint256 newReserveMeme = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveMeme / newReserveBase;
        uint256 amountOut = reserveMeme - newReserveMeme;

        if (amountOut < minAmountOut) revert Meme__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveMeme = newReserveMeme;

        emit Meme__Buy(msg.sender, to, amountIn, amountOut);

        if (provider != address(0)) {
            uint256 providerFee = feeBase * PROVIDER_FEE / DIVISOR;
            IERC20(base).transfer(provider, providerFee);
            uint256 protocolFee = feeBase * PROTOCOL_FEE / DIVISOR;
            IERC20(base).transfer(IMemeFactory(factory).treasury(), protocolFee);
            _updateBase(feeBase - providerFee - protocolFee); 
        } else {
            uint256 protocolFee = feeBase * PROTOCOL_FEE / DIVISOR;
            IERC20(base).transfer(IMemeFactory(factory).treasury(), protocolFee);
            _updateBase(feeBase - protocolFee);
        }
        IERC20(base).transferFrom(msg.sender, address(this), amountIn - feeBase);
        _mint(to, amountOut);
    }

    function sell(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        uint256 feeMeme = amountIn * FEE / DIVISOR;
        uint256 newReserveMeme = reserveMeme + amountIn - feeMeme;
        uint256 newReserveBase = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveMeme / newReserveMeme;
        uint256 amountOut = RESERVE_VIRTUAL_BASE + reserveBase - newReserveBase;

        if (amountOut < minAmountOut) revert Meme__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveMeme = newReserveMeme;

        emit Meme__Sell(msg.sender, to, amountIn, amountOut);

        if (provider != address(0)) {
            uint256 providerFee = feeMeme * PROVIDER_FEE / DIVISOR;
            transfer(provider, providerFee);
            uint256 protocolFee = feeMeme * PROTOCOL_FEE / DIVISOR;
            transfer(IMemeFactory(factory).treasury(), protocolFee);
            _updateMeme(feeMeme - providerFee - protocolFee);
        } else {
            uint256 protocolFee = feeMeme * PROTOCOL_FEE / DIVISOR;
            transfer(IMemeFactory(factory).treasury(), protocolFee);
            _updateMeme(feeMeme - protocolFee);
        }
        _burn(msg.sender, amountIn - feeMeme);
        IERC20(base).transfer(to, amountOut);
    }

    function claimFees(address account) external returns (uint256 claimedBase, uint256 claimedMeme) {
        _updateFor(account);

        claimedBase = claimableBase[account];
        claimedMeme = claimableMeme[account];

        if (claimedBase > 0 || claimedMeme > 0) {
            claimableBase[account] = 0;
            claimableMeme[account] = 0;

            MemeFees(fees).claimFeesFor(account, claimedBase, claimedMeme);

            emit Meme__Claim(account, claimedBase, claimedMeme);
        }
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function _updateBase(uint256 amount) internal {
        IERC20(base).transfer(fees, amount);
        totalFeesBase += amount;
        uint256 _ratio = amount * 1e18 / totalSupply();
        if (_ratio > 0) {
            indexBase += _ratio;
        }
        emit Meme__Fees(msg.sender, amount, 0);
    }

    function _updateMeme(uint256 amount) internal {
        transfer(fees, amount);
        totalFeesMeme += amount;
        uint256 _ratio = amount * 1e18 / totalSupply();
        if (_ratio > 0) {
            indexMeme += _ratio;
        }
        emit Meme__Fees(msg.sender, 0, amount);
    }
    
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf(recipient);
        if (_supplied > 0) {
            uint256 _supplyIndexBase = supplyIndexBase[recipient];
            uint256 _supplyIndexMeme = supplyIndexMeme[recipient];
            uint256 _indexBase = indexBase; 
            uint256 _indexMeme = indexMeme;
            supplyIndexBase[recipient] = _indexBase;
            supplyIndexMeme[recipient] = _indexMeme;
            uint256 _deltaBase = _indexBase - _supplyIndexBase;
            uint256 _deltaMeme = _indexMeme - _supplyIndexMeme;
            if (_deltaBase > 0) {
                uint256 _share = _supplied * _deltaBase / 1e18;
                claimableBase[recipient] += _share;
            }
            if (_deltaMeme > 0) {
                uint256 _share = _supplied * _deltaMeme / 1e18;
                claimableMeme[recipient] += _share;
            }
        } else {
            supplyIndexBase[recipient] = indexBase; 
            supplyIndexMeme[recipient] = indexMeme;
        }
    }

    /*----------  FUNCTION OVERRIDES  -----------------------------------*/

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20)
    {
        super._beforeTokenTransfer(from, to, amount);
        _updateFor(from);
        _updateFor(to);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getPrice() external view returns (uint256) {
        return ((RESERVE_VIRTUAL_BASE + reserveBase) * PRECISION) / reserveMeme;
    }

}
