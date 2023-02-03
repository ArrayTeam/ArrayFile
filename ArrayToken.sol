// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "contracts/interface/router2.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface Iinvite {
    function checkUserInvitor(address addr) external view returns (address);
}

contract ArrayToken is ERC20Upgradeable, OwnableUpgradeable {
    address public usdt;
    address public reservePool;
    address public INVITE;
    uint public ACC;
    uint private unlocked;

    mapping(address => uint) public userBid;
    mapping(address => bool) public copartner;
    mapping(address => bool) public wc;
    mapping(address => mapping(address => bool)) public getPair;
    address public banker;
    //2.0
    mapping(address => uint) public userAirdropped;
    mapping(address => uint) public userBid_T;
    mapping(address => uint) public userAirdropped_T;

    event Burn(address indexed account, bool indexed amount);
    event Sync(address indexed token, uint indexed amount);
    event SwapBuy(address indexed sender, uint amountUsdtIn, uint amountArrayOut);
    event SwapSell(
        address indexed sender,
        uint amountArrayIn,
        uint amountUsdtOut
    );
    event AirDrop(
        address indexed user,
        uint indexed amountU,
        uint indexed amountT
    );

    modifier lock() {
        require(unlocked == 1, "FintochSTO: LOCKED");

        unlocked = 0;
        _;
        unlocked = 1;
    }

    function init() external initializer {
        __ERC20_init_unchained("Array Token", "Array");
        __Context_init_unchained();
        __Ownable_init_unchained();
        _mint(msg.sender, 1000000 ether);
        setReservePool(msg.sender);
        wc[msg.sender] = true;
        ACC = 1e18;
        unlocked = 1;
    }

    // owner
    function safePull(
        address token,
        address wallet,
        uint amount
    ) external onlyOwner {
        IERC20(token).transfer(wallet, amount);
    }

    function setU(address usdt_) public onlyOwner {
        usdt = usdt_;
        getPair[usdt][address(this)] = true;
        getPair[address(this)][usdt] = true;
    }

    function setReservePool(address addr_) public onlyOwner {
        reservePool = addr_;
        wc[addr_] = true;
    }

    function setBanker(address banker_) public onlyOwner {
        banker = banker_;
    }

    function setWC(address[] memory addr_, bool b_) public onlyOwner {
        for (uint i; i < addr_.length; i++) {
            wc[addr_[i]] = b_;
        }
    }

    function burn(address addr_, uint amount_) public {
        require(wc[msg.sender], "nonono");
        _burn(addr_, amount_);
    }

    /////////////
    //// swap////
    /////////////

    function addLiquuidity(uint inputU_) public {
        (uint _t, uint _u, ) = getReserves();
        uint k = _t * _u;
        uint inputT_ = k / inputU_;
        _transfer(msg.sender, address(this), inputT_);
        IERC20(usdt).transferFrom(msg.sender, address(this), inputU_);
    }

    // public
    function sync(address tokenAddr, uint256 amount) external onlyOwner {
        emit Sync(tokenAddr, amount);
    }

    function buy(
        uint amountIn_,
        uint amountOutMin,
        address to_,
        uint total_,
        uint time_,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external lock returns (uint amountOut) {
        uint poolArrayBal = balanceOf(address(this));
        uint poolUSDTBal = IERC20(usdt).balanceOf(address(this));

        // buy
        bytes32 _hash = keccak256(
            abi.encodePacked(amountIn_, total_, time_, msg.sender)
        );
        address a = ecrecover(_hash, v, r, s);
        require(a == banker, "no banker");
        uint amountIn = amountIn_;
        amountOut = getAmountOut(amountIn, poolUSDTBal, poolArrayBal);
        if (!wc[msg.sender] || !wc[to_]) {
            require(userBid[msg.sender] + amountIn < total_, "out of total");
        }
        userBid[msg.sender] += amountIn;
        userBid_T[msg.sender] += amountOut;

        require(amountOut >= amountOutMin, "Array: INSUFFICIENT_OUTPUT_AMOUNT");

        bool success = IERC20(usdt).transferFrom(
            msg.sender,
            address(this),
            amountIn
        );
        require(success, "TRANSFER_FAILED");
        _transfer(address(this), to_, amountOut);
        emit SwapBuy(msg.sender, amountIn, amountOut);
    }

    function sell(
        uint amountIn_,
        uint amountOutMin,
        address to_
    ) external lock returns (uint amountOut) {
        // sell
        require(balanceOf(msg.sender) > 0, "balance is 0");
        uint poolArrayBal = balanceOf(address(this));
        uint poolUSDTBal = IERC20(usdt).balanceOf(address(this));

        amountOut = getAmountOut(amountIn_, poolArrayBal, poolUSDTBal);
        require(amountOut >= amountOutMin, "Array: INSUFFICIENT_OUTPUT_AMOUNT");

        _transfer(msg.sender, address(this), amountIn_);

        IERC20(usdt).transfer(to_, amountOut);
        emit SwapSell(msg.sender, amountIn_, amountOut);
    }

    //airdrop
    function claimAirDrop(
        uint reward_,
        uint totalReward_,
        uint time_,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        bytes32 _hash = keccak256(
            abi.encodePacked(reward_, totalReward_, time_, msg.sender)
        );
        address a = ecrecover(_hash, v, r, s);
        require(a == banker, "no banker");
        require(
            totalReward_ >= reward_ + userAirdropped[msg.sender],
            "out of limit"
        );
        uint _p = getPrice();
        uint amountT = (reward_ * ACC) / _p;
        userAirdropped[msg.sender] += reward_;
        userAirdropped_T[msg.sender] += amountT;
        _transfer(address(this), msg.sender, amountT);

        emit AirDrop(msg.sender, reward_, amountT);
    }

    // view
    function getPrice() public view returns (uint price) {
        uint poolArray = balanceOf(address(this));
        uint poolUSDT = IERC20(usdt).balanceOf(address(this));
        price = (poolUSDT * ACC) / poolArray;
    }

    function getReserves()
        public
        view
        returns (uint256 poolArray, uint256 poolUSDT, uint256 blockTimestamp)
    {
        poolArray = balanceOf(address(this));
        poolUSDT = IERC20(usdt).balanceOf(address(this));
        return (poolArray, poolUSDT, block.timestamp);
    }

    function getAmountOut(
        uint amountIn_,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountOut) {
        require(amountIn_ > 0, "Array: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Array: INSUFFICIENT_LIQUIDITY");
        uint numerator = amountIn_ * (reserveOut);
        uint denominator = reserveIn + (amountIn_);
        amountOut = numerator / denominator;
    }

    function getamountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure returns (uint amountIn_) {
        require(amountOut > 0, "Array: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "Array: INSUFFICIENT_LIQUIDITY");
        uint numerator = reserveIn * (amountOut);
        uint denominator = reserveOut / (amountOut);
        amountIn_ = (numerator / denominator) + 1;
    }
}
