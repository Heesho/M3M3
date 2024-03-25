// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IHenloFactory {
    function treasury() external view returns (address);
}

contract PreKey is ReentrancyGuard {
    uint256 public constant DURATION = 3600;
    
    address public immutable base;
    address public immutable key;

    uint256 public immutable endTimestamp;
    bool public ended = false;

    uint256 public totalKeyBalance;
    uint256 public totalBaseContributed;
    mapping(address => uint256) public account_BaseContributed;

    error PreKey__ZeroInput();
    error PreKey__Concluded();
    error PreKey__InProgress();
    error PreKey__NotEligible();

    event PreKey__Contributed(address indexed account, uint256 amount);
    event PreKey__MarketOpened(address indexed key, uint256 totalKeyBalance, uint256 totalBaseContributed);
    event PreKey__Redeemed(address indexed account, uint256 amount);

    constructor(address _base) {
        base = _base;
        key = msg.sender;
        endTimestamp = block.timestamp + DURATION;
    }

    function contribute(address account, uint256 amount) external nonReentrant {
        if (amount == 0) revert PreKey__ZeroInput();
        if (ended) revert PreKey__Concluded();
        totalBaseContributed += amount;
        account_BaseContributed[account] += amount;
        IERC20(base).transferFrom(msg.sender, address(this), amount);
        emit PreKey__Contributed(account, amount);
    }

    function openMarket() external {
        if (endTimestamp > block.timestamp) revert PreKey__InProgress();
        if (ended) revert PreKey__Concluded();
        ended = true;
        IERC20(base).approve(key, totalBaseContributed);
        Key(key).buy(totalBaseContributed, 0, 0, address(this), address(0));
        totalKeyBalance = IERC20(key).balanceOf(address(this));
        Key(key).openMarket();
        emit PreKey__MarketOpened(key, totalKeyBalance, totalBaseContributed);
    }

    function redeem(address account) external nonReentrant {
        if (!ended) revert PreKey__InProgress();
        uint256 contribution = account_BaseContributed[account];
        if (contribution == 0) revert PreKey__NotEligible();
        account_BaseContributed[account] = 0;
        uint256 keyAmount = totalKeyBalance * contribution / totalBaseContributed;
        IERC20(key).transfer(account, keyAmount);
        emit PreKey__Redeemed(account, keyAmount);
    }
    
}

contract KeyFees {

    address internal immutable base;
    address internal immutable key;

    constructor(address _base) {
        key = msg.sender;
        base = _base;
    }

    function claimFeesFor(address recipient, uint amountBase) external {
        require(msg.sender == key);
        if (amountBase > 0) IERC20(base).transfer(recipient, amountBase);
    }

}

contract Key is ERC20, ERC20Permit, ERC20Votes, ReentrancyGuard {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant PRECISION = 1e18;
    uint256 public constant RESERVE_VIRTUAL_BASE = 100 * PRECISION;
    uint256 public constant INITIAL_SUPPLY = 1000000 * PRECISION;
    uint256 public constant FEE = 100;
    uint256 public constant FEE_AMOUNT = 2000;
    uint256 public constant DIVISOR = 10000;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable base;
    address public immutable fees;
    address public immutable henloFactory;
    address public immutable preKey;

    uint256 public maxSupply = INITIAL_SUPPLY;
    bool public open = false;

    // bonding curve state
    uint256 public reserveBase = 0;
    uint256 public reserveKey = INITIAL_SUPPLY;

    // fees state
    uint256 public totalFeesBase;
    uint256 public indexBase;
    mapping(address => uint256) public supplyIndexBase;
    mapping(address => uint256) public claimableBase;

    // borrowing
    uint256 public totalDebt;
    mapping(address => uint256) public account_Debt;

    /*----------  ERRORS ------------------------------------------------*/

    error Key__ZeroInput();
    error Key__Expired();
    error Key__SlippageToleranceExceeded();
    error Key__MarketNotOpen();
    error Key__NotAuthorized();
    error Key__OutstandingDebt();
    error Key__CreditLimit();

    /*----------  EVENTS ------------------------------------------------*/

    event Key__Buy(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut);
    event Key__Sell(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut);
    event Key__Fees(address indexed account, uint256 amountBase, uint256 amountKey);
    event Key__Claim(address indexed account, uint256 amountBase);
    event Key__StatusUpdated(address indexed account, string status);
    event Key__StatusFee(address indexed account, uint256 amountBase);
    event Key__ProviderFee(address indexed account, uint256 amountBase);
    event Key__ProtocolFee(address indexed account, uint256 amountBase);
    event Key__Burn(address indexed account, uint256 amountKey);
    event Key__Borrow(address indexed account, uint256 amountBase);
    event Key__Repay(address indexed account, uint256 amountBase);

    /*----------  MODIFIERS  --------------------------------------------*/

    modifier notExpired(uint256 expireTimestamp) {
        if (expireTimestamp != 0 && expireTimestamp < block.timestamp) revert Key__Expired();
        _;
    }

    modifier notZeroInput(uint256 _amount) {
        if (_amount == 0) revert Key__ZeroInput();
        _;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(string memory _name, string memory _symbol, address _base, address _henloFactory)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        henloFactory = _henloFactory;
        base = _base;
        fees = address(new KeyFees(_base));
        preKey = address(new PreKey(_base));
    }

    function buy(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        if (!open && msg.sender != preKey) revert Key__MarketNotOpen();

        uint256 feeBase = amountIn * FEE / DIVISOR;
        uint256 newReserveBase = RESERVE_VIRTUAL_BASE + reserveBase + amountIn - feeBase;
        uint256 newReserveKey = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveKey / newReserveBase;
        uint256 amountOut = reserveKey - newReserveKey;

        if (amountOut < minAmountOut) revert Key__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveKey = newReserveKey;

        emit Key__Buy(msg.sender, to, amountIn, amountOut);

        IERC20(base).transferFrom(msg.sender, address(this), amountIn);
        if (provider != address(0)) {
            uint256 feeAmount = feeBase * FEE_AMOUNT / DIVISOR;

            IERC20(base).transfer(provider, feeAmount);
            emit Key__ProviderFee(provider, feeAmount);
            IERC20(base).transfer(IHenloFactory(henloFactory).treasury(), feeAmount);
            emit Key__ProtocolFee(IHenloFactory(henloFactory).treasury(), feeAmount);

            feeBase -= (2 * feeAmount);
        } else {
            uint256 feeAmount = feeBase * FEE_AMOUNT / DIVISOR;

            IERC20(base).transfer(IHenloFactory(henloFactory).treasury(), feeAmount);
            emit Key__ProtocolFee(IHenloFactory(henloFactory).treasury(), feeAmount);
            feeBase -= feeAmount;
        }
        _mint(to, amountOut);
        _updateBase(feeBase); 
    }

    function sell(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        uint256 feeKey = amountIn * FEE / DIVISOR;
        uint256 newReserveKey = reserveKey + amountIn - feeKey;
        uint256 newReserveBase = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveKey / newReserveKey;
        uint256 amountOut = RESERVE_VIRTUAL_BASE + reserveBase - newReserveBase;

        if (amountOut < minAmountOut) revert Key__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveKey = newReserveKey;

        emit Key__Sell(msg.sender, to, amountIn, amountOut);

        _burn(msg.sender, amountIn - feeKey);
        burnKey(feeKey);
        IERC20(base).transfer(to, amountOut);
    }

    function borrow(uint256 amountBase) 
        external 
        nonReentrant
        notZeroInput(amountBase)
    {
        uint256 credit = getAccountCredit(msg.sender);
        if (credit < amountBase) revert Key__CreditLimit();
        totalDebt += amountBase;
        account_Debt[msg.sender] += amountBase;
        emit Key__Borrow(msg.sender, amountBase);
        IERC20(base).transfer(msg.sender, amountBase);
    }

    function repay(uint256 amountBase) 
        external 
        nonReentrant
        notZeroInput(amountBase)
    {
        totalDebt -= amountBase;
        account_Debt[msg.sender] -= amountBase;
        emit Key__Repay(msg.sender, amountBase);
        IERC20(base).transferFrom(msg.sender, address(this), amountBase);
    }

    function claimFees(address account) 
        external 
        returns (uint256 claimedBase) 
    {
        _updateFor(account);

        claimedBase = claimableBase[account];

        if (claimedBase > 0) {
            claimableBase[account] = 0;

            KeyFees(fees).claimFeesFor(account, claimedBase);

            emit Key__Claim(account, claimedBase);
        }
    }

    function burnKey(uint256 amount) 
        public 
        notZeroInput(amount)
    {
        maxSupply -= amount;
        _burn(msg.sender, amount);
        emit Key__Burn(msg.sender, amount);
    }

    function donate(uint256 amount) 
        external 
        notZeroInput(amount)
    {
        IERC20(base).transferFrom(msg.sender, address(this), amount);
        _updateBase(amount);
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function openMarket() external {
        if (msg.sender != preKey) revert Key__NotAuthorized();
        open = true;
    }

    function _updateBase(uint256 amount) internal {
        IERC20(base).transfer(fees, amount);
        totalFeesBase += amount;
        uint256 _ratio = amount * 1e18 / totalSupply();
        if (_ratio > 0) {
            indexBase += _ratio;
        }
        emit Key__Fees(msg.sender, amount, 0);
    }
    
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf(recipient);
        if (_supplied > 0) {
            uint256 _supplyIndexBase = supplyIndexBase[recipient];
            uint256 _indexBase = indexBase; 
            supplyIndexBase[recipient] = _indexBase;
            uint256 _deltaBase = _indexBase - _supplyIndexBase;
            if (_deltaBase > 0) {
                uint256 _share = _supplied * _deltaBase / 1e18;
                claimableBase[recipient] += _share;
            }
        } else {
            supplyIndexBase[recipient] = indexBase; 
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
        if (account_Debt[from] > 0) revert Key__OutstandingDebt();
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

    function getMarketPrice() external view returns (uint256) {
        return ((RESERVE_VIRTUAL_BASE + reserveBase) * PRECISION) / reserveKey;
    }

    function getFloorPrice() external view returns (uint256) {
        return (RESERVE_VIRTUAL_BASE * PRECISION) / maxSupply;
    }

    function getAccountCredit(address account) public view returns (uint256) {
        if (balanceOf(account) == 0) return 0;
        return ((RESERVE_VIRTUAL_BASE * INITIAL_SUPPLY / (INITIAL_SUPPLY - balanceOf(account))) - RESERVE_VIRTUAL_BASE) - account_Debt[account];
    }

}

contract KeyFactory {

    address public immutable henloFactory;
    address public lastKey;

    error KeyFactory__Unauthorized();

    event KeyFactory__KeyCreated(address key);

    constructor(address _henloFactory) {
        henloFactory = _henloFactory;
    }

    function createKey(
        string memory name,
        string memory symbol,
        address base
    ) external returns (address) {
        if (msg.sender != henloFactory) revert KeyFactory__Unauthorized();

        lastKey = address(new Key(name, symbol, base, henloFactory));
        emit KeyFactory__KeyCreated(lastKey);

        return lastKey;
    }
}